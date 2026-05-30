import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: BatterySnapshot = .unavailable
    @Published var backendStatus: ChargeBackendStatus = .unknown
    @Published var selectedLimit: ChargeLimitPreset = .recommendedNetwork
    @Published var selectedDelta: Int = 5
    @Published var isACGuardModeEnabled = false
    @Published var isACGuardSuspended = false
    @Published var warningMessage: String?
    @Published var lastError: String?
    @Published var selectedTab: AppTab = .status
    @Published var isWaitingForBackendRefresh = false

    let monitor: PowerSourceMonitor
    let logger: EventLogger
    let batteryLabRecorder: BatteryLabRecorder
    private let backend: ChargeLimitController
    private var timer: Timer?
    private var previousACConnected: Bool?
    private var hasLoggedDischargeWarning = false
    private var hasLoggedLowReserveWarning = false

    init(logger: EventLogger = EventLogger()) {
        let runner = ShellCommandRunner()
        monitor = PowerSourceMonitor(runner: runner)
        self.logger = logger
        backend = BackendDetector(runner: runner).detect()
        batteryLabRecorder = BatteryLabRecorder(monitor: monitor, logger: logger)

        logger.log(.appStarted, "Mac AC Guard started.")
        logger.log(.backendDetected, "Detected backend: \(backend.getBackendName()).")
        refreshStatus()
        startMonitoring()
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

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    func refreshStatus() {
        snapshot = monitor.snapshot()
        updateBackendStatus()
        syncSelectionsFromActualStatus()
        evaluateSafetyState()
    }

    func enableACMode() {
        refreshStatus()

        guard snapshot.isACConnected, snapshot.powerSourceType == .ac else {
            showError("Режим не включён: адаптер питания не подключён или macOS не видит AC Power.")
            return
        }

        guard (snapshot.batteryPercent ?? 0) >= 30 else {
            let message = "Режим не включён: заряд батареи ниже 30%."
            warningMessage = "Резерв батареи ниже безопасного уровня."
            logger.log(.batteryBelowSafetyThreshold, message)
            return
        }

        guard backend.isAvailable() else {
            showError("На этом Mac доступен только мониторинг. Управление лимитом зарядки недоступно безопасным способом.")
            return
        }

        do {
            try backend.setChargeLimit(percent: selectedLimit.rawValue)
            logger.log(.limitChanged, "Charge limit changed to \(selectedLimit.rawValue)%.")
            try backend.setLowerLimitDelta(percent: selectedDelta)
            logger.log(.lowerLimitDeltaChanged, "Lower-limit delta changed to \(selectedDelta)%.")
            isACGuardModeEnabled = true
            isACGuardSuspended = false
            lastError = nil
            warningMessage = selectedLimit.warning
            logger.log(.modeEnabled, "AC Guard mode enabled at \(selectedLimit.rawValue)% with delta \(selectedDelta)%.")
            scheduleBackendVerification(requestedUpper: selectedLimit.rawValue, requestedDelta: selectedDelta)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func disableACMode() {
        do {
            if backend.isAvailable() {
                try backend.disableChargeLimit()
            }
            isACGuardModeEnabled = false
            isACGuardSuspended = false
            logger.log(.modeDisabled, "AC Guard mode disabled.")
            refreshStatus()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func applySelectedLimit() {
        guard backend.isAvailable() else {
            showError("На этом Mac доступен только мониторинг. Управление лимитом зарядки недоступно безопасным способом.")
            return
        }

        do {
            try backend.setChargeLimit(percent: selectedLimit.rawValue)
            logger.log(.limitChanged, "Charge limit changed to \(selectedLimit.rawValue)%.")
            try backend.setLowerLimitDelta(percent: selectedDelta)
            logger.log(.lowerLimitDeltaChanged, "Lower-limit delta changed to \(selectedDelta)%.")
            warningMessage = selectedLimit.warning
            scheduleBackendVerification(requestedUpper: selectedLimit.rawValue, requestedDelta: selectedDelta)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func openLogsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([eventLogURL])
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
        guard !backendStatus.battDisabled else { return }

        if let upper = backendStatus.actualUpperLimitPercent,
           let preset = ChargeLimitPreset(rawValue: upper) {
            selectedLimit = preset
        }

        if let delta = backendStatus.actualLowerLimitDeltaPercent,
           [2, 5, 10].contains(delta) {
            selectedDelta = delta
        }
    }

    private func scheduleBackendVerification(requestedUpper: Int, requestedDelta: Int) {
        isWaitingForBackendRefresh = true
        warningMessage = "Command sent. Waiting for backend refresh."

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            refreshStatus()
            verifyActualLimit(requestedUpper: requestedUpper, requestedDelta: requestedDelta)

            try? await Task.sleep(for: .seconds(3))
            refreshStatus()
            verifyActualLimit(requestedUpper: requestedUpper, requestedDelta: requestedDelta)
            isWaitingForBackendRefresh = false
        }
    }

    private func verifyActualLimit(requestedUpper: Int, requestedDelta: Int) {
        let requestedLower = requestedUpper - requestedDelta
        guard backendStatus.isAvailable else { return }

        if backendStatus.actualUpperLimitPercent == requestedUpper,
           backendStatus.actualLowerLimitPercent == requestedLower {
            warningMessage = selectedLimit.warning
            lastError = nil
            return
        }

        if backendStatus.rawStatusText?.localizedCaseInsensitiveContains("refreshes can take up to 2 minutes") == true {
            warningMessage = "Command sent. Waiting for backend refresh."
            return
        }

        let actualUpper = backendStatus.actualUpperLimitPercent.map { "\($0)%" } ?? "unknown"
        let actualLower = backendStatus.actualLowerLimitPercent.map { "\($0)%" } ?? "unknown"
        warningMessage = "Requested \(requestedUpper)/\(requestedLower)%, but backend reports \(actualUpper)/\(actualLower)."
    }

    private func evaluateSafetyState() {
        if let previousACConnected, previousACConnected != snapshot.isACConnected {
            logger.log(snapshot.isACConnected ? .acConnected : .acDisconnected, snapshot.isACConnected ? "AC connected." : "AC disconnected.")
        }
        previousACConnected = snapshot.isACConnected

        if isACGuardModeEnabled, !snapshot.isACConnected {
            isACGuardModeEnabled = false
            isACGuardSuspended = true
            warningMessage = "Зарядка отключена. Режим «Работа от сети» аварийно приостановлен."
            logger.log(.acDisconnected, "AC Guard mode suspended because AC disconnected.")
        }

        if snapshot.isBatteryDischargingWhileOnAC {
            warningMessage = "Адаптер не покрывает текущую нагрузку. Аккумулятор участвует в питании."
            if !hasLoggedDischargeWarning {
                logger.log(.batteryStartedDischargingWhileACConnected, warningMessage ?? "")
                hasLoggedDischargeWarning = true
            }
        } else {
            hasLoggedDischargeWarning = false
        }

        if let percent = snapshot.batteryPercent, percent < 30 {
            warningMessage = "Резерв батареи ниже безопасного уровня."
            if !hasLoggedLowReserveWarning {
                logger.log(.batteryBelowSafetyThreshold, "Battery reserve below 30%: \(percent)%.")
                hasLoggedLowReserveWarning = true
            }
        } else {
            hasLoggedLowReserveWarning = false
        }
    }

    private func showError(_ message: String) {
        lastError = message
        logger.log(.error, message)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case status = "Status"
    case lab = "Battery Lab"
    case settings = "Settings"

    var id: String { rawValue }
}
