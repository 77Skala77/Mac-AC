import XCTest
@testable import MacACGuard

final class PowerSourceParserTests: XCTestCase {
    func testBatterySnapshotComputesSignedBatteryPower() {
        let snapshot = BatterySnapshot(
            voltageMillivolts: 12_300,
            amperageMilliamps: -500
        )

        XCTAssertNotNil(snapshot.batteryPowerWatts)
        XCTAssertEqual(snapshot.batteryPowerWatts!, -6.15, accuracy: 0.0001)
    }

    func testDetectsBatteryDischargingWhileOnAC() {
        let snapshot = BatterySnapshot(
            isACConnected: true,
            powerSourceType: .ac,
            amperageMilliamps: -250
        )

        XCTAssertTrue(snapshot.isBatteryDischargingWhileOnAC)
    }
}
