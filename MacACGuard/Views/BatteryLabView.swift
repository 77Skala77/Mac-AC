import AppKit
import SwiftUI

struct BatteryLabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedMode: BatteryLabMode = .acGuardGameTest
    @State private var selectedDurationMinutes = 15
    @State private var customDurationMinutes = 15
    @State private var useCustomDuration = false
    @State private var gameProcessName = ""
    @State private var startButtonLocked = false

    private var recorder: BatteryLabRecorder {
        appState.batteryLabRecorder
    }

    private var durationSeconds: TimeInterval {
        TimeInterval((useCustomDuration ? customDurationMinutes : selectedDurationMinutes) * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery Lab")
                .font(.headline)

            Picker("Test", selection: $selectedMode) {
                ForEach(BatteryLabMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Duration", selection: $selectedDurationMinutes) {
                Text("5").tag(5)
                Text("10").tag(10)
                Text("15").tag(15)
                Text("20").tag(20)
            }
            .pickerStyle(.segmented)
            .disabled(useCustomDuration)

            Toggle("Custom duration", isOn: $useCustomDuration)
            if useCustomDuration {
                Stepper("\(customDurationMinutes) min", value: $customDurationMinutes, in: 1...180)
            }

            TextField("Game process name optional", text: $gameProcessName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    startButtonLocked = true
                    do {
                        try recorder.start(
                            mode: selectedMode,
                            durationSeconds: durationSeconds,
                            gameProcessName: gameProcessName,
                            selectedChargeLimit: appState.selectedLimit.rawValue,
                            selectedLowerLimitDelta: appState.selectedDelta,
                            backendName: appState.backendName,
                            appModeActiveProvider: { appState.isACGuardModeEnabled },
                            backendStatusProvider: { appState.backendStatus }
                        )
                    } catch {
                        recorder.lastError = error.localizedDescription
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1))
                        startButtonLocked = false
                    }
                } label: {
                    Label("Start Test", systemImage: "play.fill")
                }
                .disabled(recorder.isRecording || startButtonLocked)

                Button {
                    recorder.stop(save: true)
                } label: {
                    Label("Stop Test", systemImage: "stop.fill")
                }
                .disabled(!recorder.isRecording)
            }

            GroupBox {
                VStack(spacing: 8) {
                    StatusRow(title: "Samples", value: "\(recorder.samples.count)")
                    if let last = recorder.samples.last {
                        StatusRow(title: "Elapsed", value: String(format: "%.0f s", last.elapsedSeconds))
                        StatusRow(title: "Battery", value: last.batteryPercent.map { "\($0)%" } ?? "Unknown")
                        StatusRow(title: "Battery power", value: last.batteryPowerWatts.map { String(format: "%.2f W", $0) } ?? "Unknown")
                        StatusRow(title: "Current", value: last.currentMilliamps.map { String(format: "%.0f mA", $0) } ?? "Unknown")
                        StatusRow(title: "Actual guard", value: last.actualGuardActive == true ? "Active" : "Inactive")
                    } else {
                        StatusRow(title: "Elapsed", value: "-")
                        StatusRow(title: "Battery", value: "-")
                    }
                }
            }

            if let report = recorder.lastReport {
                TestReportView(report: report)
            }

            HStack {
                Button {
                    _ = recorder.compareLatestGuardedToBaseline()
                } label: {
                    Label("Compare Tests", systemImage: "chart.bar.xaxis")
                }

                Button {
                    openExportFolder()
                } label: {
                    Label("Export CSV/JSON", systemImage: "folder")
                }
                .disabled(recorder.lastCSVURL == nil && recorder.lastJSONURL == nil)
            }

            if let csv = recorder.lastCSVURL {
                Text("CSV: \(csv.path)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let json = recorder.lastJSONURL {
                Text("JSON: \(json.path)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let error = recorder.lastError {
                Label(error, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let comparison = recorder.lastComparison {
                GroupBox("Comparison") {
                    VStack(spacing: 8) {
                        StatusRow(title: "\(comparison.baselineTitle ?? "Baseline") throughput", value: String(format: "%.6f Wh", comparison.normalReport.batteryThroughputWh))
                        StatusRow(title: "AC Guard throughput", value: String(format: "%.6f Wh", comparison.guardedReport.batteryThroughputWh))
                        StatusRow(title: "\(comparison.baselineTitle ?? "Baseline") movement", value: percentMovementText(comparison.normalReport))
                        StatusRow(title: "AC Guard movement", value: percentMovementText(comparison.guardedReport))
                        if let guardedLimitResult = comparison.guardedLimitResult {
                            StatusRow(title: "Target result", value: guardedLimitResult)
                        }
                        StatusRow(title: "\(comparison.baselineTitle ?? "Baseline") energy in", value: String(format: "%.6f Wh", comparison.normalReport.batteryEnergyInWh))
                        StatusRow(title: "Guarded energy out", value: String(format: "%.6f Wh", comparison.guardedReport.batteryEnergyOutWh))
                        StatusRow(title: "Reduction", value: comparison.participationReductionPercent.map { String(format: "%.2f%%", $0) } ?? "Unavailable")
                        if let summary = comparison.summary {
                            Text(summary)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(comparison.interpretation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func percentMovementText(_ report: BatteryLabReport) -> String {
        guard let start = report.startingBatteryPercent, let finish = report.finalBatteryPercent else {
            return "Unknown"
        }
        return "\(start)% to \(finish)%"
    }

    private func openExportFolder() {
        if let csv = recorder.lastCSVURL {
            NSWorkspace.shared.activateFileViewerSelecting([csv])
        } else if let json = recorder.lastJSONURL {
            NSWorkspace.shared.activateFileViewerSelecting([json])
        }
    }
}
