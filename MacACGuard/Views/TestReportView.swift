import SwiftUI

struct TestReportView: View {
    var report: BatteryLabReport

    var body: some View {
        GroupBox("Summary") {
            VStack(spacing: 8) {
                StatusRow(title: "Start charge", value: report.startingBatteryPercent.map { "\($0)%" } ?? "Unknown")
                StatusRow(title: "Final charge", value: report.finalBatteryPercent.map { "\($0)%" } ?? "Unknown")
                StatusRow(title: "Percent delta", value: report.batteryPercentDelta.map { "\($0)%" } ?? "Unknown")
                StatusRow(title: "Energy in", value: String(format: "%.3f Wh", report.batteryEnergyInWh))
                StatusRow(title: "Energy out", value: String(format: "%.3f Wh", report.batteryEnergyOutWh))
                StatusRow(title: "Throughput", value: String(format: "%.3f Wh", report.batteryThroughputWh))
                StatusRow(title: "Battery Participation Index", value: String(format: "%.3f Wh", report.batteryParticipationIndexWh))
                StatusRow(title: "Quality", value: report.qualityLabel?.rawValue ?? "Informative")
                StatusRow(title: "UI mode active", value: report.uiModeActive == true ? "Yes" : "No")
                StatusRow(title: "Actual guard active", value: report.actualGuardActive == true ? "Yes" : "No")
                if let upper = report.actualChargeUpperLimitPercent {
                    let lower = report.actualChargeLowerLimitPercent.map { "\($0)" } ?? "unknown"
                    StatusRow(title: "Actual backend limit", value: report.battDisabled == true ? "batt disabled / 100%" : "\(lower)-\(upper)%")
                }
                if let reduction = report.reductionPercentComparedToBaseline {
                    StatusRow(title: "Reduction", value: String(format: "%.2f%%", reduction))
                }
                if let maxTemperature = report.maxBatteryTemperatureCelsius {
                    StatusRow(title: "Max battery temp", value: String(format: "%.1f C", maxTemperature))
                }
                if let avgPower = report.avgBatteryPowerWatts {
                    StatusRow(title: "Avg battery power", value: String(format: "%.2f W", avgPower))
                }
                if let avgCurrent = report.avgCurrentMilliamps {
                    StatusRow(title: "Avg current", value: String(format: "%.0f mA", avgCurrent))
                }
                if let notes = report.qualityNotes, !notes.isEmpty {
                    Text(notes.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let interpretation {
                    Text(interpretation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var interpretation: String? {
        switch report.testMode {
        case .batteryOnlyGameTest where report.batteryEnergyOutWh > 1:
            return "Battery-only gaming used the battery directly during this test."
        case .acGuardGameTest where report.batteryThroughputWh < 0.05:
            return "Battery participation was near zero. The Mac appears to be powered almost entirely by the adapter during this test."
        case .acGuardGameTest:
            if let target = report.actualChargeUpperLimitPercent,
               let start = report.startingBatteryPercent,
               let finish = report.finalBatteryPercent {
                return ReportGenerator().formatBatteryLimitResult(target: target, start: start, finish: finish).capitalizedFirst + "."
            }
            return nil
        case .normalChargingGameTest where report.batteryEnergyInWh > 1:
            return "Battery was actively charging during this test."
        default:
            if let reduction = report.reductionPercentComparedToBaseline, reduction > 95 {
                return "AC Guard greatly reduced battery participation compared to normal charging."
            }
            return nil
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }
}
