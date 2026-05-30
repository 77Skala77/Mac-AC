import XCTest
@testable import MacACGuard

final class ReportGeneratorTests: XCTestCase {
    func testBatteryParticipationReduction() {
        let reduction = ReportGenerator().reductionPercent(guardedThroughput: 0.7, baselineThroughput: 8.0)
        XCTAssertNotNil(reduction)
        XCTAssertEqual(reduction!, 91.25, accuracy: 0.0001)
    }

    func testBatteryParticipationReductionHandlesZeroBaseline() {
        let reduction = ReportGenerator().reductionPercent(guardedThroughput: 0.7, baselineThroughput: 0)
        XCTAssertNil(reduction)
    }

    func testCompareReportsShowsRealWorldReduction() {
        let generator = ReportGenerator()
        let normal = report(mode: .normalChargingGameTest, throughput: 10.524986705215039, energyIn: 10.524986705215039, energyOut: 0)
        let guarded = report(mode: .acGuardGameTest, throughput: 0.0011711552411482068, energyIn: 0, energyOut: 0.0011711552411482068)

        let comparison = generator.compare(normal: normal, guarded: guarded)

        XCTAssertNotNil(comparison.participationReductionPercent)
        XCTAssertEqual(comparison.participationReductionPercent!, 99.98887262000972, accuracy: 0.000001)
        XCTAssertTrue(comparison.interpretation.contains("greatly reduced"))
    }

    func testCleanHeavyGameReduction() {
        let generator = ReportGenerator()
        let baseline = report(
            mode: .batteryOnlyGameTest,
            start: 70,
            finish: 49,
            throughput: 17.491994721367643,
            energyIn: 0,
            energyOut: 17.491994721367643
        )
        let guarded = report(
            mode: .acGuardGameTest,
            start: 70,
            finish: 71,
            throughput: 0.44195659128976483,
            energyIn: 0.3493896283269021,
            energyOut: 0.09256696296286274,
            actualUpper: 70,
            actualLower: 65,
            actualGuardActive: true
        )

        let comparison = generator.compare(normal: baseline, guarded: guarded)

        XCTAssertNotNil(comparison.participationReductionPercent)
        XCTAssertEqual(comparison.participationReductionPercent!, 97.47337797472643, accuracy: 0.000001)
        XCTAssertTrue(comparison.interpretation.contains("17.49 Wh"))
        XCTAssertTrue(comparison.interpretation.contains("0.44 Wh"))
        XCTAssertTrue(comparison.interpretation.contains("around the 70% target limit"))
        XCTAssertTrue(comparison.interpretation.contains("70–71%"))
    }

    func testBatteryLimitFormattingUsesAroundForRoundedOnePercentMovement() {
        let text = ReportGenerator().formatBatteryLimitResult(target: 70, start: 70, finish: 71)

        XCTAssertTrue(text.contains("around the 70% target limit"))
        XCTAssertTrue(text.contains("70–71%"))
    }

    func testACGuardSeventyToSeventyOneIsClean() {
        let test = BatteryLabTest(
            mode: .acGuardGameTest,
            plannedDurationSeconds: 900,
            gameProcessName: nil,
            selectedChargeLimit: 70,
            selectedLowerLimitDelta: 5,
            backendName: "batt (Apple Silicon)"
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
            currentChargePercent: 70,
            batteryStateText: "not charging"
        )
        let start = Date()
        let samples = [
            sample(test: test, timestamp: start, percent: 70, isACConnected: true, powerSourceType: .ac, backendStatus: status, actualGuardActive: true),
            sample(test: test, timestamp: start.addingTimeInterval(900), percent: 71, isACConnected: true, powerSourceType: .ac, backendStatus: status, actualGuardActive: true)
        ]

        let report = ReportGenerator().generate(samples: samples)

        XCTAssertEqual(report.qualityLabel, .clean)
        XCTAssertEqual(report.observedBatteryMinimumPercent, 70)
        XCTAssertEqual(report.observedBatteryMaximumPercent, 71)
    }

    func testBatteryOnlyHeavyGameIsClean() {
        let test = BatteryLabTest(
            mode: .batteryOnlyGameTest,
            plannedDurationSeconds: 900,
            gameProcessName: nil,
            selectedChargeLimit: 70,
            selectedLowerLimitDelta: 5,
            backendName: "batt (Apple Silicon)"
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
            battDisabled: false
        )
        let start = Date()
        let samples = [
            sample(test: test, timestamp: start, percent: 70, isACConnected: false, powerSourceType: .battery, backendStatus: status, actualGuardActive: false),
            sample(test: test, timestamp: start.addingTimeInterval(900), percent: 49, isACConnected: false, powerSourceType: .battery, backendStatus: status, actualGuardActive: false)
        ]

        let report = ReportGenerator().generate(samples: samples)

        XCTAssertEqual(report.qualityLabel, .clean)
    }

    private func report(
        mode: BatteryLabMode,
        start: Int? = nil,
        finish: Int? = nil,
        throughput: Double,
        energyIn: Double,
        energyOut: Double,
        actualUpper: Int? = nil,
        actualLower: Int? = nil,
        actualGuardActive: Bool? = nil
    ) -> BatteryLabReport {
        BatteryLabReport(
            testId: UUID(),
            testMode: mode,
            startedAt: Date(),
            finishedAt: Date(),
            sampleCount: 1,
            startingBatteryPercent: start,
            finalBatteryPercent: finish,
            batteryPercentDelta: optionalDelta(start, finish),
            batteryEnergyInWh: energyIn,
            batteryEnergyOutWh: energyOut,
            batteryThroughputWh: throughput,
            netBatteryChangeWh: energyIn - energyOut,
            drainRatePercentPerHour: nil,
            maxBatteryTemperatureCelsius: nil,
            avgBatteryPowerWatts: nil,
            avgCurrentMilliamps: nil,
            batteryParticipationIndexWh: throughput,
            reductionPercentComparedToBaseline: nil,
            actualChargeUpperLimitPercent: actualUpper,
            actualChargeLowerLimitPercent: actualLower,
            actualChargeDeltaPercent: optionalDelta(actualLower, actualUpper),
            battDisabled: nil,
            uiModeActive: nil,
            actualGuardActive: actualGuardActive,
            observedBatteryMinimumPercent: [start, finish].compactMap { $0 }.min(),
            observedBatteryMaximumPercent: [start, finish].compactMap { $0 }.max(),
            qualityLabel: nil,
            qualityNotes: nil,
            errors: []
        )
    }

    private func sample(
        test: BatteryLabTest,
        timestamp: Date,
        percent: Int,
        isACConnected: Bool,
        powerSourceType: PowerSourceType,
        backendStatus: ChargeBackendStatus,
        actualGuardActive: Bool
    ) -> BatteryLabSample {
        let snapshot = BatterySnapshot(
            timestamp: timestamp,
            batteryPercent: percent,
            isACConnected: isACConnected,
            powerSourceType: powerSourceType,
            isCharging: false,
            voltageMillivolts: 12_000,
            amperageMilliamps: 0
        )
        return BatteryLabSample(
            test: test,
            snapshot: snapshot,
            elapsedSeconds: timestamp.timeIntervalSince(test.startedAt),
            appModeActive: false,
            backendStatus: backendStatus,
            actualGuardActive: actualGuardActive
        )
    }

    private func optionalDelta(_ start: Int?, _ end: Int?) -> Int? {
        guard let start, let end else { return nil }
        return end - start
    }
}
