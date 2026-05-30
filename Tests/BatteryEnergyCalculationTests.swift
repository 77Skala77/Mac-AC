import XCTest
@testable import MacACGuard

final class BatteryEnergyCalculationTests: XCTestCase {
    func testEnergyOutUsesNegativeBatteryPower() {
        let test = BatteryLabTest(
            mode: .normalChargingGameTest,
            plannedDurationSeconds: 600,
            gameProcessName: nil,
            selectedChargeLimit: nil,
            selectedLowerLimitDelta: nil,
            backendName: "test"
        )
        let start = Date()
        let samples = [
            sample(test: test, timestamp: start, power: -12, percent: 70),
            sample(test: test, timestamp: start.addingTimeInterval(600), power: -12, percent: 68)
        ]

        let report = ReportGenerator().generate(samples: samples)

        XCTAssertEqual(report.batteryEnergyOutWh, 2.0, accuracy: 0.0001)
        XCTAssertEqual(report.batteryEnergyInWh, 0, accuracy: 0.0001)
        XCTAssertEqual(report.batteryThroughputWh, 2.0, accuracy: 0.0001)
        XCTAssertEqual(report.netBatteryChangeWh, -2.0, accuracy: 0.0001)
    }

    func testEnergyInUsesPositiveBatteryPower() {
        let test = BatteryLabTest(
            mode: .acGuardGameTest,
            plannedDurationSeconds: 300,
            gameProcessName: nil,
            selectedChargeLimit: 60,
            selectedLowerLimitDelta: 5,
            backendName: "test"
        )
        let start = Date()
        let samples = [
            sample(test: test, timestamp: start, power: 6, percent: 60),
            sample(test: test, timestamp: start.addingTimeInterval(300), power: 6, percent: 61)
        ]

        let report = ReportGenerator().generate(samples: samples)

        XCTAssertEqual(report.batteryEnergyInWh, 0.5, accuracy: 0.0001)
        XCTAssertEqual(report.batteryEnergyOutWh, 0, accuracy: 0.0001)
        XCTAssertEqual(report.batteryThroughputWh, 0.5, accuracy: 0.0001)
    }

    func testDeadbandTreatsNearZeroAsNoParticipation() {
        let test = BatteryLabTest(
            mode: .acGuardGameTest,
            plannedDurationSeconds: 300,
            gameProcessName: nil,
            selectedChargeLimit: 60,
            selectedLowerLimitDelta: 5,
            backendName: "test"
        )
        let start = Date()
        let samples = [
            sample(test: test, timestamp: start, power: 0.1, percent: 60),
            sample(test: test, timestamp: start.addingTimeInterval(300), power: -0.1, percent: 60)
        ]

        let report = ReportGenerator().generate(samples: samples)

        XCTAssertEqual(report.batteryThroughputWh, 0, accuracy: 0.0001)
    }

    private func sample(test: BatteryLabTest, timestamp: Date, power: Double, percent: Int) -> BatteryLabSample {
        let voltage = 12_000.0
        let current = power / 12.0 * 1_000.0
        let snapshot = BatterySnapshot(
            timestamp: timestamp,
            batteryPercent: percent,
            isACConnected: true,
            powerSourceType: .ac,
            isCharging: power > 0,
            voltageMillivolts: voltage,
            amperageMilliamps: current
        )
        return BatteryLabSample(
            test: test,
            snapshot: snapshot,
            elapsedSeconds: timestamp.timeIntervalSince(test.startedAt),
            appModeActive: true
        )
    }
}
