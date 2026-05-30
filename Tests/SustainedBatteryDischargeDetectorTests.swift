import XCTest
@testable import MacACGuard

final class SustainedBatteryDischargeDetectorTests: XCTestCase {
    func testSingleSmallNegativeSampleDoesNotTriggerWarning() {
        var detector = SustainedBatteryDischargeDetector()

        let assessment = detector.evaluate(
            timestamp: Date(),
            batteryPowerWatts: -7,
            isACConnected: true,
            isGuardSessionActive: true
        )

        XCTAssertEqual(assessment, .stable)
    }

    func testSmallNegativeSamplesRemainBelowWarningThreshold() {
        var detector = SustainedBatteryDischargeDetector()
        let start = Date()

        let assessment = evaluate(&detector, start: start, watts: -7, seconds: [0, 10, 20, 30])

        XCTAssertEqual(assessment, .stable)
    }

    func testSustainedDischargeBelowThresholdTriggersWarning() throws {
        var detector = SustainedBatteryDischargeDetector()
        let start = Date()

        let assessment = evaluate(&detector, start: start, watts: -15, seconds: [0, 10, 20])

        XCTAssertEqual(assessment, .sustainedBatteryDischarge)
        XCTAssertEqual(try XCTUnwrap(detector.averagePowerWatts), -15, accuracy: 0.001)
    }

    func testWarningClearsWhenRollingAverageRecovers() throws {
        var detector = SustainedBatteryDischargeDetector()
        let start = Date()
        _ = evaluate(&detector, start: start, watts: -15, seconds: [0, 10, 20])

        let assessment = detector.evaluate(
            timestamp: start.addingTimeInterval(31),
            batteryPowerWatts: 0,
            isACConnected: true,
            isGuardSessionActive: true
        )

        XCTAssertEqual(assessment, .stable)
        XCTAssertEqual(try XCTUnwrap(detector.averagePowerWatts), -7.5, accuracy: 0.001)
    }

    private func evaluate(
        _ detector: inout SustainedBatteryDischargeDetector,
        start: Date,
        watts: Double,
        seconds: [TimeInterval]
    ) -> AdapterLoadAssessment {
        seconds.reduce(.stable) { _, seconds in
            detector.evaluate(
                timestamp: start.addingTimeInterval(seconds),
                batteryPowerWatts: watts,
                isACConnected: true,
                isGuardSessionActive: true
            )
        }
    }
}
