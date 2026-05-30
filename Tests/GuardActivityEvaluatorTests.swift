import XCTest
@testable import MacACGuard

final class GuardActivityEvaluatorTests: XCTestCase {
    func testActualGuardActiveWhenBattLimitHoldingAtUpperLimit() {
        let snapshot = BatterySnapshot(
            batteryPercent: 80,
            isACConnected: true,
            powerSourceType: .ac,
            isCharging: false,
            voltageMillivolts: 12_100,
            amperageMilliamps: 0
        )
        let status = ChargeBackendStatus(
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
            currentChargePercent: 80,
            batteryStateText: "not charging"
        )

        XCTAssertTrue(GuardActivityEvaluator.isActualGuardActive(snapshot: snapshot, backendStatus: status))
    }

    func testActualGuardInactiveWhenBattDisabledAndCharging() {
        let snapshot = BatterySnapshot(
            batteryPercent: 83,
            isACConnected: true,
            powerSourceType: .ac,
            isCharging: true,
            voltageMillivolts: 12_660,
            amperageMilliamps: 3_300
        )
        let status = ChargeBackendStatus(
            backendName: "batt (Apple Silicon)",
            isAvailable: true,
            isMonitorOnly: false,
            currentLimit: 100,
            lowerLimitDelta: nil,
            requiresPrivileges: true,
            details: "test",
            lastError: nil,
            actualUpperLimitPercent: 100,
            battDisabled: true,
            allowCharging: true,
            usePowerAdapter: true,
            currentChargePercent: 83,
            batteryStateText: "charging"
        )

        XCTAssertFalse(GuardActivityEvaluator.isActualGuardActive(snapshot: snapshot, backendStatus: status))
    }
}
