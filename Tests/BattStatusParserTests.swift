import XCTest
@testable import MacACGuard

final class BattStatusParserTests: XCTestCase {
    func testParsesACGuardActiveSeventySixtyFive() {
        let status = BattStatusParser().parse(
            Self.acGuardActiveStatus,
            backendName: "batt (Apple Silicon)",
            battPath: "/opt/homebrew/bin/batt",
            homebrewInstallationDetected: true
        )

        XCTAssertEqual(status.allowCharging, false)
        XCTAssertEqual(status.usePowerAdapter, true)
        XCTAssertEqual(status.currentChargePercent, 70)
        XCTAssertEqual(status.batteryStateText, "not charging")
        XCTAssertEqual(status.chargeRateWatts, 0.0)
        XCTAssertEqual(status.voltageVolts, 12.10)
        XCTAssertEqual(status.battDisabled, false)
        XCTAssertEqual(status.actualUpperLimitPercent, 70)
        XCTAssertEqual(status.actualLowerLimitPercent, 65)
        XCTAssertEqual(status.actualLowerLimitDeltaPercent, 5)
        XCTAssertEqual(status.allowNonRootUsers, false)
        XCTAssertEqual(status.battPath, "/opt/homebrew/bin/batt")
        XCTAssertTrue(status.homebrewInstallationDetected)
        XCTAssertNotNil(status.warning)
    }

    func testParsesBattDisabledNormalCharging() {
        let status = BattStatusParser().parse(
            Self.battDisabledStatus,
            backendName: "batt (Apple Silicon)",
            battPath: "/opt/homebrew/bin/batt",
            homebrewInstallationDetected: true
        )

        XCTAssertEqual(status.allowCharging, true)
        XCTAssertEqual(status.usePowerAdapter, true)
        XCTAssertEqual(status.currentChargePercent, 83)
        XCTAssertEqual(status.batteryStateText, "charging")
        XCTAssertEqual(status.chargeRateWatts, 42.7)
        XCTAssertEqual(status.voltageVolts, 12.66)
        XCTAssertEqual(status.battDisabled, true)
        XCTAssertEqual(status.actualUpperLimitPercent, 100)
        XCTAssertNil(status.actualLowerLimitPercent)
        XCTAssertNil(status.actualLowerLimitDeltaPercent)
        XCTAssertEqual(status.allowNonRootUsers, false)
    }

    func testParsesChargingToEighty() {
        let status = BattStatusParser().parse(
            Self.chargingToEightyStatus,
            backendName: "batt (Apple Silicon)",
            battPath: "/opt/homebrew/bin/batt",
            homebrewInstallationDetected: true
        )

        XCTAssertEqual(status.allowCharging, true)
        XCTAssertEqual(status.usePowerAdapter, true)
        XCTAssertEqual(status.currentChargePercent, 42)
        XCTAssertEqual(status.batteryStateText, "charging")
        XCTAssertEqual(status.chargeRateWatts, 107.4)
        XCTAssertEqual(status.battDisabled, false)
        XCTAssertEqual(status.actualUpperLimitPercent, 80)
        XCTAssertEqual(status.actualLowerLimitPercent, 78)
        XCTAssertEqual(status.actualLowerLimitDeltaPercent, 2)
        XCTAssertEqual(status.allowNonRootUsers, false)
    }

    private static let acGuardActiveStatus = """
    Charging status:
      Allow charging: ✘ (refreshes can take up to 2 minutes)
        Your Mac will not charge even if you plug in, because your current charge is above the limit.
      Use power adapter: ✔
        Your Mac will use power from the wall (to operate or charge), if it is plugged in.

    Battery status:
      Current charge: 70%
      State: not charging
      Full capacity: 7459 mAh
      Charge rate: +0.0 W
      Voltage: 12.10 V

    Battery configuration:
      Upper limit: 70%
      Lower limit: 65%
      Prevent idle-sleep when charging: ✔
      Disable charging before sleep if charge limit is enabled: ✔
      Prevent system-sleep when charging: ✘
      Allow non-root users to access the daemon: ✘
      Control MagSafe LED: ✘
    """

    private static let battDisabledStatus = """
    Charging status:
      Allow charging: ✔ (refreshes can take up to 2 minutes)
        Your Mac will charge.
      Use power adapter: ✔
        Your Mac will use power from the wall (to operate or charge), if it is plugged in.

    Battery status:
      Current charge: 83%
      State: charging
      Full capacity: 7459 mAh
      Charge rate: +42.7 W
      Voltage: 12.66 V

    Battery configuration:
      Charge limit: 100% (batt disabled)
      Prevent idle-sleep when charging: ✔
      Disable charging before sleep if charge limit is enabled: ✔
      Prevent system-sleep when charging: ✘
      Allow non-root users to access the daemon: ✘
      Control MagSafe LED: ✘
    """

    private static let chargingToEightyStatus = """
    Charging status:
      Allow charging: ✔ (refreshes can take up to 2 minutes)
        Your Mac will charge.
      Use power adapter: ✔
        Your Mac will use power from the wall (to operate or charge), if it is plugged in.

    Battery status:
      Current charge: 42%
      Time to limit (80%): ~19 minutes
      State: charging
      Full capacity: 7446 mAh
      Charge rate: +107.4 W
      Voltage: 12.20 V

    Battery configuration:
      Upper limit: 80%
      Lower limit: 78%
      Prevent idle-sleep when charging: ✔
      Disable charging before sleep if charge limit is enabled: ✔
      Prevent system-sleep when charging: ✘
      Allow non-root users to access the daemon: ✘
      Control MagSafe LED: ✘
    """
}
