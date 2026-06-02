import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: BatterySnapshot = .unavailable
    @Published var backendStatus: ChargeBackendStatus = .unknown
    @Published var writeAccess: ChargeWriteAccess = .monitorOnly
    @Published var selectedLimit: ChargeLimitPreset = .recommendedNetwork
    @Published var selectedDelta = 5
    @Published var lastAutoSelectedLimit: Int?
    @Published var lastAutoSelectedDelta: Int?
    @Published var requestedMode: RequestedGuardMode = .none
    @Published var userRequestedAutoGuard = false
    @Published var configuredPending = false
    @Published var lastStopReason: GuardStopReason?
    @Published var isACGuardModeEnabled = false
    @Published var isACGuardSuspended = false
    @Published var userNotice: UserNotice?
    @Published var lastError: String?
    @Published var selectedTab: AppTab = .status
    @Published var isWaitingForBackendRefresh = false
    @Published var isPermissionSetupPresented = false
    @Published var permissionSetupMessage: String?
    @Published var isPopoverPresented = false
    @Published var adapterLoadAssessment: AdapterLoadAssessment = .stable
    @Published var adapterLoadAverageWatts: Double?
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: AppLanguage.defaultsKey)
        }
    }

    let monitor: any PowerSnapshotProviding
    let logger: EventLogger
    let batteryLabRecorder: BatteryLabRecorder
    private let backend: ChargeLimitController
    private let defaults: UserDefaults
    private let commandGenerator = ManualSetupCommandGenerator()
    private var timer: Timer?
    private var timerInterval: TimeInterval?
    private var monitoringEnabled = false
    private var liveTickCount = 0
    private var previousACConnected: Bool?
    private var hasLoggedDischargeWarning = false
    private var hasLoggedLowReserveWarning = false
    private var verificationTask: Task<Void, Never>?
    private var dischargeDetector = SustainedBatteryDischargeDetector()

    init(
        logger: EventLogger = EventLogger(),
        monitor: (any PowerSnapshotProviding)? = nil,
        backend: ChargeLimitController? = nil,
        defaults: UserDefaults = .standard,
        startMonitoring: Bool = true,
        performInitialRefresh: Bool = true
    ) {
        let runner = ShellCommandRunner()
        let resolvedMonitor = monitor ?? PowerSourceMonitor(runner: runner)
        self.monitor = resolvedMonitor
        self.logger = logger
        self.backend = backend ?? BackendDetector(runner: runner).detect()
        self.defaults = defaults
        self.language = AppLanguage.persisted(in: defaults)
        batteryLabRecorder = BatteryLabRecorder(monitor: resolvedMonitor, logger: logger)

        logger.log(.appStarted, "Mac AC Guard started.")
        logger.log(.backendDetected, "Detected backend: \(self.backend.getBackendName()).")
        if performInitialRefresh {
            refreshStatus()
        }
        if startMonitoring {
            self.startMonitoring()
        }
    }

    var backendName: String {
        backend.getBackendName()
    }

    var eventLogURL: URL {
        logger.logURL
    }

    var actualGuardActive: Bool {
        GuardActivityEvaluator.isActualGuardActive(snapshot: snapshot, backendStatus: backendStatus)
    }

    var shouldShowPermissionSetup: Bool {
        isPermissionSetupPresented || writeAccess.backend == .manualSetupRequired
    }

    var manualSetupCommands: String {
        let limit: Int
        let delta: Int

        if requestedMode == .auto {
            limit = lastAutoSelectedLimit ?? selectedLimit.rawValue
            delta = lastAutoSelectedDelta ?? AutoGuardLimitSelector.defaultDelta
        } else {
            limit = selectedLimit.rawValue
            delta = selectedDelta
        }

        return (try? commandGenerator.instructions(limit: limit, delta: delta)) ?? ""
    }

    var warningMessage: String? {
        userNotice.map { text($0.localizationKey) }
    }

    var liveMonitoringInterval: TimeInterval {
        desiredMonitoringInterval
    }

    func text(_ key: L10nKey) -> String {
        L10n.text(key, language)
    }

    func format(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: language == .ru ? "ru_RU" : "en_US"), arguments: arguments)
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        language = newLanguage
    }

    func setPopoverPresented(_ presented: Bool) {
        isPopoverPresented = presented
        if presented {
            refreshStatus()
        }
        updateMonitoringTimer()
    }

    func startMonitoring() {
        monitoringEnabled = true
        updateMonitoringTimer(force: true)
    }

    /// Full status refresh. This is strictly read-only.
    func refreshStatus() {
        snapshot = monitor.snapshot()
        updateBackendStatus()
        writeAccess = backend.getWriteAccess()
        syncSelectionsFromActualStatus()
        evaluateSafetyState()
        syncModeFromActualStatus()
        updateMonitoringTimer()
    }

    /// Lightweight IOKit polling path. It never calls backend write methods.
    func performLiveMonitoringTick() {
        snapshot = monitor.snapshot()
        liveTickCount += 1
        let acChanged = previousACConnected != nil && previousACConnected != snapshot.isACConnected
        if acChanged || liveTickCount.isMultiple(of: 4) {
            updateBackendStatus()
            writeAccess = backend.getWriteAccess()
            syncSelectionsFromActualStatus()
        }
        evaluateSafetyState()
        syncModeFromActualStatus()
        updateMonitoringTimer()
    }

    func enableACMode() {
        resetRequestedVisualState()
        requestedMode = .auto
        userRequestedAutoGuard = true
        refreshStatus()

        guard snapshot.isACConnected, snapshot.powerSourceType == .ac else {
            requestedMode = .none
            userRequestedAutoGuard = false
            userNotice = .connectAdapter
            return
        }

        guard let batteryPercent = snapshot.batteryPercent, batteryPercent >= 5 else {
            requestedMode = .none
            userRequestedAutoGuard = false
            userNotice = .reserveBelowSafe
            logger.log(.batteryBelowSafetyThreshold, "AC Guard was not enabled because battery reserve is below 5%.")
            return
        }

        let autoLimit = AutoGuardLimitSelector.limit(for: batteryPercent)
        let autoDelta = AutoGuardLimitSelector.defaultDelta
        lastAutoSelectedLimit = autoLimit
        lastAutoSelectedDelta = autoDelta
        guard prepareForWrite() else {
            userRequestedAutoGuard = false
            return
        }
        applyConfiguration(limit: autoLimit, delta: autoDelta)
    }

    func disableACMode() {
        verificationTask?.cancel()
        guard prepareForWrite() else {
            isACGuardModeEnabled = actualGuardActive
            return
        }

        do {
            try backend.disableChargeLimit()
            logger.log(.modeDisabled, "AC Guard mode disable requested.")
            requestedMode = .none
            userRequestedAutoGuard = false
            configuredPending = false
            isACGuardModeEnabled = false
            isACGuardSuspended = false
            userNotice = nil
            lastError = nil
            refreshStatus()
        } catch {
            handleWriteError(error)
            refreshStatus()
        }
    }

    func applySelectedLimit() {
        requestedMode = .manual
        userRequestedAutoGuard = false
        guard prepareForWrite() else { return }
        applyConfiguration(limit: selectedLimit.rawValue, delta: selectedDelta)
    }

    func grantPermission() {
        isPermissionSetupPresented = true
        userNotice = .permissionRequired
        permissionSetupMessage = text(.helperPackagingUnavailable)
        writeAccess = ChargeWriteAccess(
            backend: .manualSetupRequired,
            authorizationState: .helperNeedsInstall,
            lastWriteError: permissionSetupMessage
        )
    }

    func useTerminalSetupInstead() {
        isPermissionSetupPresented = true
        userNotice = .permissionRequired
        permissionSetupMessage = text(.helperPackagingUnavailable)
    }

    func copySetupCommands() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(manualSetupCommands, forType: .string)
        permissionSetupMessage = text(.setupCommandsCopied)
    }

    func openTerminalInstructions() {
        copySetupCommands()
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.openApplication(at: terminalURL, configuration: NSWorkspace.OpenConfiguration())
    }

    func openLogsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([eventLogURL])
    }

    func prepareForTermination() {
        verificationTask?.cancel()
        timer?.invalidate()
        logger.flush()
    }

    private var desiredMonitoringInterval: TimeInterval {
        isPopoverPresented || isACGuardModeEnabled || configuredPending ? 2 : 8
    }

    private func updateMonitoringTimer(force: Bool = false) {
        guard monitoringEnabled else { return }
        let interval = desiredMonitoringInterval
        guard force || timerInterval != interval else { return }

        timer?.invalidate()
        timerInterval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performLiveMonitoringTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func applyConfiguration(limit: Int, delta: Int) {
        do {
            try backend.setChargeLimit(percent: limit)
            logger.log(.limitChanged, "Charge limit changed to \(limit)%.")
            try backend.setLowerLimitDelta(percent: delta)
            logger.log(.lowerLimitDeltaChanged, "Lower-limit delta changed to \(delta)%.")
            try backend.enableAdapter()
            logger.log(.adapterEnabled, "Adapter mode enabled.")
            configuredPending = snapshot.isACConnected
            isACGuardModeEnabled = configuredPending
            isPermissionSetupPresented = false
            permissionSetupMessage = nil
            userNotice = .configuredCheckingPower
            lastError = nil
            scheduleBackendVerification(requestedUpper: limit, requestedDelta: delta)
            updateMonitoringTimer()
        } catch {
            handleWriteError(error)
        }
    }

    private func prepareForWrite() -> Bool {
        writeAccess = backend.getWriteAccess()
        guard backend.isAvailable() else {
            userNotice = .monitorOnly
            lastError = text(.monitorOnly)
            return false
        }

        switch writeAccess.backend {
        case .directBatt, .privilegedHelper:
            return true
        case .manualSetupRequired:
            showPermissionSetup(writeAccess.lastWriteError)
            return false
        case .monitorOnly:
            userNotice = .monitorOnly
            lastError = text(.monitorOnly)
            return false
        }
    }

    private func updateBackendStatus() {
        do {
            backendStatus = try backend.getStatus()
        } catch {
            backendStatus = ChargeBackendStatus(
                backendName: backend.getBackendName(),
                isAvailable: false,
                isMonitorOnly: true,
                currentLimit: nil,
                lowerLimitDelta: nil,
                requiresPrivileges: true,
                details: "Backend status unavailable.",
                lastError: error.localizedDescription
            )
        }
    }

    private func syncSelectionsFromActualStatus() {
        guard requestedMode == .none, !backendStatus.battDisabled else { return }

        if let upper = backendStatus.actualUpperLimitPercent,
           let preset = ChargeLimitPreset(rawValue: upper) {
            selectedLimit = preset
        }

        if let delta = backendStatus.actualLowerLimitDeltaPercent,
           [1, 2, 5, 10].contains(delta) {
            selectedDelta = delta
        }
    }

    private func scheduleBackendVerification(requestedUpper: Int, requestedDelta: Int) {
        verificationTask?.cancel()
        isWaitingForBackendRefresh = true
        userNotice = .configuredCheckingPower

        verificationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            refreshStatus()
            verifyActualLimit(requestedUpper: requestedUpper, requestedDelta: requestedDelta)

            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            refreshStatus()
            verifyActualLimit(requestedUpper: requestedUpper, requestedDelta: requestedDelta)
            isWaitingForBackendRefresh = false
            syncModeFromActualStatus()
        }
    }

    private func verifyActualLimit(requestedUpper: Int, requestedDelta: Int) {
        let requestedLower = requestedUpper - requestedDelta
        guard requestedMode != .none, backendStatus.isAvailable, snapshot.isACConnected else { return }

        if backendStatus.actualUpperLimitPercent == requestedUpper,
           backendStatus.actualLowerLimitPercent == requestedLower {
            if actualGuardActive {
                configuredPending = false
                isACGuardModeEnabled = true
                userNotice = nil
                lastError = nil
                logger.log(.modeEnabled, "AC Guard mode confirmed active at \(requestedUpper)% with delta \(requestedDelta)%.")
            } else {
                configuredPending = true
                isACGuardModeEnabled = true
                userNotice = .configuredCheckingPower
            }
            return
        }

        configuredPending = snapshot.isACConnected
        isACGuardModeEnabled = configuredPending
        userNotice = .configuredCheckingPower
        let actualUpper = backendStatus.actualUpperLimitPercent.map { "\($0)%" } ?? "unknown"
        let actualLower = backendStatus.actualLowerLimitPercent.map { "\($0)%" } ?? "unknown"
        lastError = "Requested \(requestedUpper)/\(requestedLower)%, but backend reports \(actualUpper)/\(actualLower)."
    }

    private func evaluateSafetyState() {
        let priorAC = previousACConnected
        let isACConnected = snapshot.isACConnected && snapshot.powerSourceType == .ac
        let wasRequestedOrRunning = requestedMode != .none || configuredPending || isACGuardModeEnabled

        if let priorAC, priorAC != isACConnected {
            logger.log(isACConnected ? .acConnected : .acDisconnected, isACConnected ? "AC connected." : "AC disconnected.")
        }
        previousACConnected = isACConnected

        if priorAC == true, !isACConnected {
            verificationTask?.cancel()
            resetAdapterLoadAssessment()
            isWaitingForBackendRefresh = false
            configuredPending = false
            isACGuardModeEnabled = false
            isACGuardSuspended = wasRequestedOrRunning
            requestedMode = .none
            userRequestedAutoGuard = false
            lastStopReason = .adapterDisconnected
            if wasRequestedOrRunning {
                userNotice = .adapterDisconnectedStopped
                logger.log(.acGuardStoppedAdapterDisconnected, "Power adapter disconnected. AC Guard stopped.")
            }
            updateMonitoringTimer()
            return
        }

        if priorAC == false, isACConnected {
            resetAdapterLoadAssessment()
            isACGuardSuspended = false
            userNotice = .adapterConnectedEnableAgain
            updateMonitoringTimer()
        }

        guard isACConnected else {
            resetAdapterLoadAssessment()
            configuredPending = false
            isACGuardModeEnabled = false
            if userNotice == .adapterConnectedEnableAgain {
                userNotice = nil
            }
            return
        }

        adapterLoadAssessment = dischargeDetector.evaluate(
            timestamp: snapshot.timestamp,
            batteryPowerWatts: snapshot.batteryPowerWatts,
            isACConnected: true,
            isGuardSessionActive: requestedMode != .none && (actualGuardActive || configuredPending || isACGuardModeEnabled)
        )
        adapterLoadAverageWatts = dischargeDetector.averagePowerWatts

        if adapterLoadAssessment == .sustainedBatteryDischarge {
            userNotice = .adapterInsufficient
            if !hasLoggedDischargeWarning {
                logger.log(.batteryStartedDischargingWhileACConnected, text(.adapterInsufficient))
                hasLoggedDischargeWarning = true
            }
        } else {
            hasLoggedDischargeWarning = false
            if userNotice == .adapterInsufficient {
                userNotice = nil
            }
        }

        if let percent = snapshot.batteryPercent, percent < 5 {
            userNotice = .reserveBelowSafe
            if !hasLoggedLowReserveWarning {
                logger.log(.batteryBelowSafetyThreshold, "Battery reserve below 5%: \(percent)%.")
                hasLoggedLowReserveWarning = true
            }
        } else {
            hasLoggedLowReserveWarning = false
        }
    }

    private func syncModeFromActualStatus() {
        guard snapshot.isACConnected, snapshot.powerSourceType == .ac else {
            configuredPending = false
            isACGuardModeEnabled = false
            return
        }

        guard requestedMode != .none else {
            configuredPending = false
            isACGuardModeEnabled = actualGuardActive
            return
        }

        if actualGuardActive {
            configuredPending = false
            isACGuardModeEnabled = true
            isACGuardSuspended = false
        } else if configuredPending {
            isACGuardModeEnabled = true
        } else {
            isACGuardModeEnabled = false
        }
    }

    private func resetRequestedVisualState() {
        verificationTask?.cancel()
        configuredPending = false
        isACGuardModeEnabled = false
        isACGuardSuspended = false
        userRequestedAutoGuard = false
        userNotice = nil
        lastError = nil
    }

    private func handleWriteError(_ error: Error) {
        configuredPending = false
        isACGuardModeEnabled = false
        userRequestedAutoGuard = false
        writeAccess = backend.getWriteAccess()
        if case ChargeLimitError.privilegesRequired = error {
            showPermissionSetup(error.localizedDescription)
        } else {
            userNotice = .failedApplyLimit
            lastError = error.localizedDescription
            logger.log(.error, error.localizedDescription)
        }
        updateMonitoringTimer()
    }

    private func showPermissionSetup(_ message: String?) {
        configuredPending = false
        isACGuardModeEnabled = false
        userRequestedAutoGuard = false
        isPermissionSetupPresented = true
        userNotice = .permissionRequired
        permissionSetupMessage = message
        lastError = nil
        logger.log(.permissionSetupRequired, message ?? "Permission setup required for batt writes.")
    }

    private func resetAdapterLoadAssessment() {
        dischargeDetector.reset()
        adapterLoadAssessment = .stable
        adapterLoadAverageWatts = nil
        hasLoggedDischargeWarning = false
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case status
    case lab
    case settings

    var id: String { rawValue }

    var localizationKey: L10nKey {
        switch self {
        case .status: .status
        case .lab: .batteryLab
        case .settings: .settings
        }
    }
}
