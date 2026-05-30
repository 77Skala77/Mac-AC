import SwiftUI

struct TestReportView: View {
    @EnvironmentObject private var appState: AppState
    var report: BatteryLabReport

    var body: some View {
        GlassCard(appState.text(.summary)) {
            VStack(spacing: 5) {
                StatusRow(title: appState.text(.startCharge), value: report.startingBatteryPercent.map { "\($0)%" } ?? appState.text(.unknown))
                StatusRow(title: appState.text(.finalCharge), value: report.finalBatteryPercent.map { "\($0)%" } ?? appState.text(.unknown))
                StatusRow(title: appState.text(.percentDelta), value: report.batteryPercentDelta.map { "\($0)%" } ?? appState.text(.unknown))
                StatusRow(title: appState.text(.energyIn), value: String(format: "%.3f Wh", report.batteryEnergyInWh))
                StatusRow(title: appState.text(.energyOut), value: String(format: "%.3f Wh", report.batteryEnergyOutWh))
                StatusRow(title: appState.text(.throughput), value: String(format: "%.3f Wh", report.batteryThroughputWh))
                StatusRow(title: appState.text(.participationIndex), value: String(format: "%.3f Wh", report.batteryParticipationIndexWh))
                StatusRow(title: appState.text(.quality), value: qualityText)
                StatusRow(title: appState.text(.uiModeActive), value: yesNo(report.uiModeActive == true))
                StatusRow(title: appState.text(.actualGuardActive), value: yesNo(report.actualGuardActive == true))
                if let upper = report.actualChargeUpperLimitPercent {
                    let lower = report.actualChargeLowerLimitPercent.map { "\($0)" } ?? appState.text(.unknown)
                    StatusRow(title: appState.text(.actualBackendLimit), value: report.battDisabled == true ? "batt disabled / 100%" : "\(lower)–\(upper)%")
                }
                if let reduction = report.reductionPercentComparedToBaseline {
                    StatusRow(title: appState.text(.reduction), value: String(format: "%.2f%%", reduction))
                }
                if let maxTemperature = report.maxBatteryTemperatureCelsius {
                    StatusRow(title: appState.text(.maxBatteryTemp), value: String(format: "%.1f C", maxTemperature))
                }
                if let avgPower = report.avgBatteryPowerWatts {
                    StatusRow(title: appState.text(.avgBatteryPower), value: String(format: "%.2f W", avgPower))
                }
                if let avgCurrent = report.avgCurrentMilliamps {
                    StatusRow(title: appState.text(.avgCurrent), value: String(format: "%.0f mA", avgCurrent))
                }
            }
        }
    }

    private var qualityText: String {
        switch report.qualityLabel ?? .informative {
        case .clean: appState.text(.clean)
        case .informative: appState.text(.informative)
        case .dirty: appState.text(.dirty)
        }
    }

    private func yesNo(_ value: Bool) -> String {
        appState.text(value ? .yes : .no)
    }
}
