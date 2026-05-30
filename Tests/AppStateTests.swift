import XCTest
@testable import MacACGuard

@MainActor
final class AppStateTests: XCTestCase {
    func testToggleActivationFailsIfACIsDisconnected() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot(isACConnected: false, source: .battery))
        let backend = FakeChargeLimitController(status: inactiveStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)

        appState.enableACMode()

        XCTAssertFalse(appState.isACGuardModeEnabled)
        XCTAssertEqual(backend.setLimitCallCount, 0)
        XCTAssertEqual(appState.warningMessage, "Подключите адаптер питания.")
    }

    func testToggleDoesNotStayOnAndShowsSetupWhenWriteNeedsAuthorization() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: inactiveStatus)
        backend.writeError = .privilegesRequired("batt requires administrator authorization.")
        let appState = makeAppState(monitor: monitor, backend: backend)

        appState.enableACMode()

        XCTAssertFalse(appState.isACGuardModeEnabled)
        XCTAssertFalse(appState.actualGuardActive)
        XCTAssertTrue(appState.shouldShowPermissionSetup)
        XCTAssertEqual(appState.writeAccess.backend, .manualSetupRequired)
        XCTAssertNil(appState.lastError)
    }

    func testRefreshStatusIsStrictlyReadOnly() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend, performInitialRefresh: false)

        appState.refreshStatus()

        XCTAssertEqual(backend.setLimitCallCount, 0)
        XCTAssertEqual(backend.setDeltaCallCount, 0)
        XCTAssertEqual(backend.enableAdapterCallCount, 0)
        XCTAssertEqual(backend.disableCallCount, 0)
        XCTAssertEqual(appState.selectedLimit, .gamingNetwork)
        XCTAssertEqual(appState.selectedDelta, 5)
    }

    func testActualGuardActiveWithoutUserSessionDoesNotTurnToggleOn() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: inactiveStatus)
        let appState = makeAppState(monitor: monitor, backend: backend, performInitialRefresh: false)
        appState.isACGuardModeEnabled = true

        appState.refreshStatus()

        XCTAssertFalse(appState.actualGuardActive)
        XCTAssertFalse(appState.isACGuardModeEnabled)

        backend.status = activeStatus
        appState.refreshStatus()

        XCTAssertTrue(appState.actualGuardActive)
        XCTAssertFalse(appState.isACGuardModeEnabled)
    }

    func testOneClickAutoGuardIgnoresManualLimitAndUsesCurrentBatteryLevel() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot(percent: 60))
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        appState.selectedLimit = .softProtection
        appState.selectedDelta = 10

        appState.enableACMode()

        XCTAssertEqual(backend.setLimitCallCount, 1)
        XCTAssertEqual(backend.setDeltaCallCount, 1)
        XCTAssertEqual(backend.enableAdapterCallCount, 1)
        XCTAssertEqual(backend.receivedLimits, [60])
        XCTAssertEqual(backend.receivedDeltas, [1])
        XCTAssertEqual(appState.lastAutoSelectedLimit, 60)
        XCTAssertEqual(appState.lastAutoSelectedDelta, 1)
        XCTAssertEqual(appState.selectedLimit, .softProtection)
        XCTAssertEqual(appState.selectedDelta, 10)
    }

    func testManualApplyStillUsesSelectedLimit() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot(percent: 60))
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        appState.selectedLimit = .softProtection
        appState.selectedDelta = 10

        appState.applySelectedLimit()

        XCTAssertEqual(backend.receivedLimits, [80])
        XCTAssertEqual(backend.receivedDeltas, [10])
        XCTAssertEqual(appState.requestedMode, .manual)
    }

    func testManualRefreshDetectsConfiguredSeventySixtyFiveState() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: inactiveStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        backend.status = activeStatus

        appState.refreshStatus()

        XCTAssertEqual(appState.backendStatus.actualUpperLimitPercent, 70)
        XCTAssertEqual(appState.backendStatus.actualLowerLimitPercent, 65)
        XCTAssertEqual(appState.selectedLimit, .gamingNetwork)
        XCTAssertEqual(appState.selectedDelta, 5)
        XCTAssertTrue(appState.actualGuardActive)
    }

    func testLiveMonitoringStopsModeWhenAdapterDisconnects() throws {
        let logURL = temporaryLogURL()
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = AppState(
            logger: EventLogger(logURL: logURL),
            monitor: monitor,
            backend: backend,
            startMonitoring: false
        )
        appState.requestedMode = .auto
        appState.userRequestedAutoGuard = true
        appState.configuredPending = true
        appState.isACGuardModeEnabled = true
        XCTAssertTrue(appState.isACGuardModeEnabled)

        monitor.currentSnapshot = batterySnapshot(isACConnected: false, source: .battery)
        appState.performLiveMonitoringTick()

        XCTAssertFalse(appState.actualGuardActive)
        XCTAssertFalse(appState.isACGuardModeEnabled)
        XCTAssertFalse(appState.configuredPending)
        XCTAssertFalse(appState.userRequestedAutoGuard)
        XCTAssertEqual(appState.requestedMode, .none)
        XCTAssertEqual(appState.lastStopReason, .adapterDisconnected)
        XCTAssertEqual(appState.warningMessage, "Адаптер отключён. Режим от сети остановлен.")
        XCTAssertTrue(try loggedKinds(at: logURL).contains(.acGuardStoppedAdapterDisconnected))
    }

    func testLiveMonitoringReconnectDoesNotSilentlyEnableMode() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        appState.requestedMode = .auto
        appState.userRequestedAutoGuard = true
        appState.configuredPending = true
        appState.isACGuardModeEnabled = true
        let initialWrites = backend.totalWriteCallCount

        monitor.currentSnapshot = batterySnapshot(isACConnected: false, source: .battery)
        appState.performLiveMonitoringTick()
        monitor.currentSnapshot = batterySnapshot()
        appState.performLiveMonitoringTick()

        XCTAssertFalse(appState.isACGuardModeEnabled)
        XCTAssertFalse(appState.configuredPending)
        XCTAssertFalse(appState.userRequestedAutoGuard)
        XCTAssertEqual(appState.requestedMode, .none)
        XCTAssertEqual(backend.totalWriteCallCount, initialWrites)
        XCTAssertEqual(appState.warningMessage, "Адаптер подключён. Можно снова включить режим от сети.")
    }

    func testExplicitEnableAfterReconnectStartsFreshAutoGuardSession() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot(percent: 67))
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        appState.requestedMode = .auto
        appState.userRequestedAutoGuard = true
        appState.configuredPending = true
        appState.isACGuardModeEnabled = true

        monitor.currentSnapshot = batterySnapshot(percent: 67, isACConnected: false, source: .battery)
        appState.performLiveMonitoringTick()
        monitor.currentSnapshot = batterySnapshot(percent: 67)
        appState.performLiveMonitoringTick()
        XCTAssertEqual(backend.totalWriteCallCount, 0)

        appState.enableACMode()

        XCTAssertEqual(backend.receivedLimits, [67])
        XCTAssertEqual(backend.receivedDeltas, [1])
        XCTAssertEqual(backend.enableAdapterCallCount, 1)
        XCTAssertTrue(appState.userRequestedAutoGuard)
        XCTAssertEqual(appState.lastAutoSelectedLimit, 67)
        XCTAssertEqual(appState.lastAutoSelectedDelta, 1)
    }

    func testShortNegativeBatteryPowerDoesNotShowAdapterWarning() {
        let start = Date()
        let monitor = FakePowerMonitor(snapshot: batterySnapshot(timestamp: start))
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        appState.requestedMode = .auto
        appState.userRequestedAutoGuard = true
        appState.configuredPending = true
        appState.isACGuardModeEnabled = true

        monitor.currentSnapshot = batterySnapshot(timestamp: start.addingTimeInterval(2), batteryPowerWatts: -7)
        appState.performLiveMonitoringTick()

        XCTAssertEqual(appState.adapterLoadAssessment, .stable)
        XCTAssertNotEqual(appState.userNotice, .adapterInsufficient)
    }

    func testSustainedBatteryDischargeShowsAndThenClearsAdapterWarning() {
        let start = Date()
        let monitor = FakePowerMonitor(snapshot: batterySnapshot(timestamp: start))
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        appState.requestedMode = .auto
        appState.userRequestedAutoGuard = true
        appState.configuredPending = true
        appState.isACGuardModeEnabled = true

        for seconds in [0.0, 10.0, 20.0] {
            monitor.currentSnapshot = batterySnapshot(timestamp: start.addingTimeInterval(seconds), batteryPowerWatts: -15)
            appState.performLiveMonitoringTick()
        }

        XCTAssertEqual(appState.adapterLoadAssessment, .sustainedBatteryDischarge)
        XCTAssertEqual(appState.userNotice, .adapterInsufficient)
        XCTAssertEqual(appState.warningMessage, "Адаптер не покрывает текущую нагрузку. Аккумулятор устойчиво участвует в питании.")

        monitor.currentSnapshot = batterySnapshot(timestamp: start.addingTimeInterval(31), batteryPowerWatts: 0)
        appState.performLiveMonitoringTick()

        XCTAssertEqual(appState.adapterLoadAssessment, .stable)
        XCTAssertNil(appState.userNotice)
    }

    func testLiveMonitoringTickIsReadOnly() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: activeStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)
        let initialWrites = backend.totalWriteCallCount

        appState.performLiveMonitoringTick()
        appState.performLiveMonitoringTick()
        appState.performLiveMonitoringTick()
        appState.performLiveMonitoringTick()

        XCTAssertEqual(backend.totalWriteCallCount, initialWrites)
    }

    func testLiveMonitoringUsesFastIntervalWhenPopoverIsOpen() {
        let monitor = FakePowerMonitor(snapshot: batterySnapshot())
        let backend = FakeChargeLimitController(status: inactiveStatus)
        let appState = makeAppState(monitor: monitor, backend: backend)

        XCTAssertEqual(appState.liveMonitoringInterval, 8)
        appState.setPopoverPresented(true)
        XCTAssertEqual(appState.liveMonitoringInterval, 2)
        appState.setPopoverPresented(false)
        XCTAssertEqual(appState.liveMonitoringInterval, 8)
    }

    private func makeAppState(
        monitor: FakePowerMonitor,
        backend: FakeChargeLimitController,
        performInitialRefresh: Bool = true
    ) -> AppState {
        AppState(
            logger: EventLogger(logURL: temporaryLogURL()),
            monitor: monitor,
            backend: backend,
            startMonitoring: false,
            performInitialRefresh: performInitialRefresh
        )
    }

    private func temporaryLogURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.jsonl")
    }

    private func batterySnapshot(
        timestamp: Date = Date(),
        percent: Int = 70,
        isACConnected: Bool = true,
        source: PowerSourceType = .ac,
        batteryPowerWatts: Double = 0
    ) -> BatterySnapshot {
        BatterySnapshot(
            timestamp: timestamp,
            batteryPercent: percent,
            isACConnected: isACConnected,
            powerSourceType: source,
            isCharging: false,
            voltageMillivolts: 12_100,
            amperageMilliamps: batteryPowerWatts / 12.1 * 1_000
        )
    }

    private func loggedKinds(at url: URL) throws -> [AppEventKind] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try data
            .split(separator: UInt8(ascii: "\n"))
            .map { try decoder.decode(AppEvent.self, from: Data($0)).kind }
    }

    private var inactiveStatus: ChargeBackendStatus {
        ChargeBackendStatus(
            backendName: "batt (Apple Silicon)",
            isAvailable: true,
            isMonitorOnly: false,
            currentLimit: 70,
            lowerLimitDelta: 5,
            requiresPrivileges: true,
            details: "test",
            lastError: nil,
            actualUpperLimitPercent: 70,
            actualLowerLimitPercent: 65,
            actualLowerLimitDeltaPercent: 5,
            battDisabled: false,
            allowCharging: true,
            usePowerAdapter: true,
            currentChargePercent: 70,
            batteryStateText: "charging"
        )
    }

    private var activeStatus: ChargeBackendStatus {
        ChargeBackendStatus(
            backendName: "batt (Apple Silicon)",
            isAvailable: true,
            isMonitorOnly: false,
            currentLimit: 70,
            lowerLimitDelta: 5,
            requiresPrivileges: true,
            details: "test",
            lastError: nil,
            actualUpperLimitPercent: 70,
            actualLowerLimitPercent: 65,
            actualLowerLimitDeltaPercent: 5,
            battDisabled: false,
            allowCharging: false,
            usePowerAdapter: true,
            currentChargePercent: 70,
            batteryStateText: "not charging"
        )
    }
}

private final class FakePowerMonitor: PowerSnapshotProviding {
    var currentSnapshot: BatterySnapshot

    init(snapshot: BatterySnapshot) {
        currentSnapshot = snapshot
    }

    func snapshot() -> BatterySnapshot {
        currentSnapshot
    }
}

private final class FakeChargeLimitController: ChargeLimitController {
    var status: ChargeBackendStatus
    var writeAccess = ChargeWriteAccess(backend: .directBatt, authorizationState: .unknown, lastWriteError: nil)
    var writeError: ChargeLimitError?
    var receivedLimits: [Int] = []
    var receivedDeltas: [Int] = []
    var setLimitCallCount = 0
    var setDeltaCallCount = 0
    var enableAdapterCallCount = 0
    var disableCallCount = 0

    var totalWriteCallCount: Int {
        setLimitCallCount + setDeltaCallCount + enableAdapterCallCount + disableCallCount
    }

    init(status: ChargeBackendStatus) {
        self.status = status
    }

    func isAvailable() -> Bool {
        status.isAvailable
    }

    func getBackendName() -> String {
        status.backendName
    }

    func getCurrentLimit() -> Int? {
        status.currentLimit
    }

    func getWriteAccess() -> ChargeWriteAccess {
        writeAccess
    }

    func setChargeLimit(percent: Int) throws {
        setLimitCallCount += 1
        if let writeError {
            writeAccess = ChargeWriteAccess(
                backend: .manualSetupRequired,
                authorizationState: .required,
                lastWriteError: writeError.localizedDescription
            )
            throw writeError
        }
        receivedLimits.append(percent)
    }

    func setLowerLimitDelta(percent: Int) throws {
        setDeltaCallCount += 1
        receivedDeltas.append(percent)
    }

    func enableAdapter() throws {
        enableAdapterCallCount += 1
    }

    func disableChargeLimit() throws {
        disableCallCount += 1
    }

    func getStatus() throws -> ChargeBackendStatus {
        status
    }
}
