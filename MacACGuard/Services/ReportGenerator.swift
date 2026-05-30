import Foundation

struct ReportGenerator {
    var zeroCurrentDeadbandWatts: Double = 0.25

    func generate(samples: [BatteryLabSample]) -> BatteryLabReport {
        guard let first = samples.first, let last = samples.last else {
            let now = Date()
            return BatteryLabReport(
                testId: UUID(),
                testMode: .acGuardGameTest,
                startedAt: now,
                finishedAt: now,
                sampleCount: 0,
                startingBatteryPercent: nil,
                finalBatteryPercent: nil,
                batteryPercentDelta: nil,
                batteryEnergyInWh: 0,
                batteryEnergyOutWh: 0,
                batteryThroughputWh: 0,
                netBatteryChangeWh: 0,
                drainRatePercentPerHour: nil,
                maxBatteryTemperatureCelsius: nil,
                avgBatteryPowerWatts: nil,
                avgCurrentMilliamps: nil,
                batteryParticipationIndexWh: 0,
                reductionPercentComparedToBaseline: nil,
                actualChargeUpperLimitPercent: nil,
                actualChargeLowerLimitPercent: nil,
                actualChargeDeltaPercent: nil,
                battDisabled: nil,
                uiModeActive: nil,
                actualGuardActive: nil,
                observedBatteryMinimumPercent: nil,
                observedBatteryMaximumPercent: nil,
                qualityLabel: .dirty,
                qualityNotes: ["No samples recorded."],
                errors: ["No samples recorded."]
            )
        }

        var energyInWh = 0.0
        var energyOutWh = 0.0

        if samples.count > 1 {
            for index in 1..<samples.count {
                let previous = samples[index - 1]
                let current = samples[index]
                let intervalHours = max(0, current.timestamp.timeIntervalSince(previous.timestamp)) / 3_600.0
                let averagePower = average(previous.batteryPowerWatts, current.batteryPowerWatts)
                guard let averagePower else { continue }
                if averagePower > zeroCurrentDeadbandWatts {
                    energyInWh += averagePower * intervalHours
                } else if averagePower < -zeroCurrentDeadbandWatts {
                    energyOutWh += abs(averagePower) * intervalHours
                }
            }
        }

        let throughput = energyInWh + energyOutWh
        let percentDelta = optionalDelta(first.batteryPercent, last.batteryPercent)
        let durationHours = max(0, last.timestamp.timeIntervalSince(first.timestamp)) / 3_600.0
        let drainRate: Double?
        if let percentDelta, durationHours > 0 {
            drainRate = Double(-percentDelta) / durationHours
        } else {
            drainRate = nil
        }

        let maxTemperature = samples.compactMap(\.batteryTemperatureCelsius).max()
        let avgPower = average(samples.compactMap(\.batteryPowerWatts))
        let avgCurrent = average(samples.compactMap(\.currentMilliamps))
        let latestActualUpper = samples.reversed().compactMap(\.actualChargeUpperLimitPercent).first
        let latestActualLower = samples.reversed().compactMap(\.actualChargeLowerLimitPercent).first
        let latestActualDelta = samples.reversed().compactMap(\.actualChargeDeltaPercent).first
        let latestBattDisabled = samples.reversed().compactMap(\.battDisabled).first
        let uiModeActive = samples.contains { $0.uiModeActive ?? $0.appModeActive }
        let actualGuardActive = samples.contains { $0.actualGuardActive == true }
        let observedPercentages = samples.compactMap(\.batteryPercent)
        let observedMinimum = observedPercentages.min()
        let observedMaximum = observedPercentages.max()

        var report = BatteryLabReport(
            testId: first.testId,
            testMode: first.testMode,
            startedAt: first.timestamp,
            finishedAt: last.timestamp,
            sampleCount: samples.count,
            startingBatteryPercent: first.batteryPercent,
            finalBatteryPercent: last.batteryPercent,
            batteryPercentDelta: percentDelta,
            batteryEnergyInWh: energyInWh,
            batteryEnergyOutWh: energyOutWh,
            batteryThroughputWh: throughput,
            netBatteryChangeWh: energyInWh - energyOutWh,
            drainRatePercentPerHour: drainRate,
            maxBatteryTemperatureCelsius: maxTemperature,
            avgBatteryPowerWatts: avgPower,
            avgCurrentMilliamps: avgCurrent,
            batteryParticipationIndexWh: throughput,
            reductionPercentComparedToBaseline: nil,
            actualChargeUpperLimitPercent: latestActualUpper,
            actualChargeLowerLimitPercent: latestActualLower,
            actualChargeDeltaPercent: latestActualDelta,
            battDisabled: latestBattDisabled,
            uiModeActive: uiModeActive,
            actualGuardActive: actualGuardActive,
            observedBatteryMinimumPercent: observedMinimum,
            observedBatteryMaximumPercent: observedMaximum,
            qualityLabel: nil,
            qualityNotes: nil,
            errors: []
        )
        let quality = qualityLabel(for: report, samples: samples)
        report.qualityLabel = quality.label
        report.qualityNotes = quality.notes
        return report
    }

    func reductionPercent(guardedThroughput: Double, baselineThroughput: Double) -> Double? {
        guard baselineThroughput > 0 else { return nil }
        return (1.0 - guardedThroughput / baselineThroughput) * 100.0
    }

    func reportByComparing(_ guarded: BatteryLabReport, baseline: BatteryLabReport) -> BatteryLabReport {
        var report = guarded
        report.reductionPercentComparedToBaseline = reductionPercent(
            guardedThroughput: guarded.batteryThroughputWh,
            baselineThroughput: baseline.batteryThroughputWh
        )
        return report
    }

    func compare(normal: BatteryLabReport, guarded: BatteryLabReport) -> BatteryLabComparison {
        let reduction = reductionPercent(
            guardedThroughput: guarded.batteryThroughputWh,
            baselineThroughput: normal.batteryThroughputWh
        )
        let baselineTitle = normal.testMode == .batteryOnlyGameTest ? "Battery Only" : "Normal charging"
        let target = guarded.actualChargeUpperLimitPercent ?? guarded.startingBatteryPercent
        let guardedLimitResult: String?
        if let target, let start = guarded.startingBatteryPercent, let finish = guarded.finalBatteryPercent {
            guardedLimitResult = formatBatteryLimitResult(target: target, start: start, finish: finish)
        } else {
            guardedLimitResult = nil
        }

        let interpretation: String
        if normal.batteryThroughputWh == 0 {
            interpretation = "Baseline throughput is zero; reduction cannot be calculated."
        } else if normal.testMode == .batteryOnlyGameTest, let reduction, let start = normal.startingBatteryPercent, let finish = normal.finalBatteryPercent {
            let guardedLimit = guardedLimitResult ?? "stayed near the configured target limit"
            interpretation = String(
                format: "Battery-only gaming drained the battery from %d%% to %d%% and used %.2f Wh from the battery. With AC Guard enabled, the battery %@, with only %.2f Wh of battery participation. That is about %.1f%% less battery participation in this test.",
                start,
                finish,
                normal.batteryThroughputWh,
                guardedLimit,
                guarded.batteryThroughputWh,
                reduction
            )
        } else if let reduction, reduction > 95 {
            interpretation = "AC Guard greatly reduced battery participation compared to normal charging."
        } else if let reduction {
            interpretation = String(format: "AC Guard reduced battery participation by %.2f%% compared to normal charging.", reduction)
        } else {
            interpretation = "Comparison is unavailable."
        }

        let summary: String?
        if normal.testMode == .batteryOnlyGameTest, let reduction {
            summary = String(
                format: "%.1f%% less battery participation: %.2f Wh vs %.2f Wh.",
                reduction,
                normal.batteryThroughputWh,
                guarded.batteryThroughputWh
            )
        } else {
            summary = nil
        }

        return BatteryLabComparison(
            normalReport: normal,
            guardedReport: guarded,
            participationReductionPercent: reduction,
            interpretation: interpretation,
            baselineTitle: baselineTitle,
            guardedLimitResult: guardedLimitResult,
            summary: summary
        )
    }

    func formatBatteryLimitResult(target: Int, start: Int, finish: Int) -> String {
        let minimum = min(start, finish)
        let maximum = max(start, finish)
        if minimum == target, maximum == target {
            return "stayed at the \(target)% target limit"
        }
        if abs(minimum - target) <= 2, abs(maximum - target) <= 2 {
            if abs(minimum - target) <= 1, abs(maximum - target) <= 1 {
                return "stayed around the \(target)% target limit (observed \(minimum)–\(maximum)%)"
            }
            return "stayed near the \(target)% target limit (observed \(minimum)–\(maximum)%)"
        }
        return "moved around the \(target)% target limit (observed \(minimum)–\(maximum)%)"
    }

    private func qualityLabel(for report: BatteryLabReport, samples: [BatteryLabSample]) -> (label: BatteryLabQualityLabel, notes: [String]) {
        var notes: [String] = []
        let duration = report.finishedAt.timeIntervalSince(report.startedAt)

        if !report.errors.isEmpty {
            notes.append("Report contains errors.")
            return (.dirty, notes)
        }
        if duration < 60 || report.sampleCount < 2 {
            notes.append("Test duration or sample count is too small for a clean run.")
            return (.informative, notes)
        }
        if report.actualChargeUpperLimitPercent == nil || report.actualChargeLowerLimitPercent == nil {
            notes.append("Actual backend limits were not recorded.")
            return (.informative, notes)
        }

        switch report.testMode {
        case .acGuardGameTest:
            guard report.actualGuardActive == true else {
                notes.append("AC Guard was not confirmed active.")
                return (.dirty, notes)
            }
            if let target = report.actualChargeUpperLimitPercent,
               let minimum = report.observedBatteryMinimumPercent ?? report.startingBatteryPercent,
               let maximum = report.observedBatteryMaximumPercent ?? report.finalBatteryPercent,
               abs(minimum - target) <= 2,
               abs(maximum - target) <= 2 {
                notes.append("Battery stayed near the configured target limit.")
                return (.clean, notes)
            }
            notes.append("Battery moved outside the target-limit tolerance.")
            return (.informative, notes)

        case .batteryOnlyGameTest:
            let onBattery = samples.allSatisfy { !$0.isACConnected && $0.powerSourceType == .battery }
            guard onBattery else {
                notes.append("Battery-only test includes AC-connected samples.")
                return (.dirty, notes)
            }
            if let target = report.actualChargeUpperLimitPercent,
               let start = report.startingBatteryPercent,
               abs(start - target) > 1 {
                notes.append("Start percentage was not within 1% of target start.")
                return (.informative, notes)
            }
            notes.append("Battery-only run stayed on battery power.")
            return (.clean, notes)

        case .normalChargingGameTest:
            notes.append("Normal charging run is useful as a baseline.")
            return (.informative, notes)
        }
    }

    private func average(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case (.some(let lhs), .some(let rhs)):
            (lhs + rhs) / 2.0
        case (.some(let value), .none), (.none, .some(let value)):
            value
        case (.none, .none):
            nil
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func optionalDelta(_ start: Int?, _ end: Int?) -> Int? {
        guard let start, let end else { return nil }
        return end - start
    }
}
