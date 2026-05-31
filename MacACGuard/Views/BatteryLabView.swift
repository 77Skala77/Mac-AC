import AppKit
import SwiftUI

struct BatteryLabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedMode: BatteryLabMode = .acGuardGameTest
    @State private var selectedDurationMinutes = 15
    @State private var customDurationMinutes = 45
    @State private var customDurationText = "45"
    @State private var useCustomDuration = false
    @State private var useInfiniteDuration = false
    @State private var gameProcessName = ""
    @State private var startButtonLocked = false

    private var recorder: BatteryLabRecorder {
        appState.batteryLabRecorder
    }

    private var durationSeconds: TimeInterval? {
        if useInfiniteDuration {
            return nil
        }

        let minutes = useCustomDuration ? sanitizedCustomDurationMinutes : selectedDurationMinutes
        return TimeInterval(minutes * 60)
    }

    private var sanitizedCustomDurationMinutes: Int {
        let parsed = Int(customDurationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? customDurationMinutes
        return min(max(parsed, 1), 720)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.text(.batteryLab))
                .font(.headline)

            Picker(appState.text(.test), selection: $selectedMode) {
                ForEach(BatteryLabMode.allCases) { mode in
                    Text(modeText(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker(appState.text(.duration), selection: $selectedDurationMinutes) {
                Text("10").tag(10)
                Text("15").tag(15)
                Text("20").tag(20)
            }
            .pickerStyle(.segmented)
            .disabled(useCustomDuration || useInfiniteDuration)

            Toggle(appState.text(.customDuration), isOn: $useCustomDuration)
                .font(.caption)
                .disabled(useInfiniteDuration)
                .onChange(of: useCustomDuration) { _, enabled in
                    if enabled {
                        useInfiniteDuration = false
                        customDurationText = "\(customDurationMinutes)"
                    }
                }

            if useCustomDuration {
                HStack(spacing: 8) {
                    TextField(appState.text(.duration), text: $customDurationText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            commitCustomDurationText()
                        }
                        .onChange(of: customDurationText) { _, newValue in
                            let filtered = newValue.filter(\.isNumber)
                            if filtered != newValue {
                                customDurationText = filtered
                            }
                        }

                    Text("мин")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("1–720")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .onDisappear {
                    commitCustomDurationText()
                }
            }

            Toggle("Бесконечный тест — до Стоп", isOn: $useInfiniteDuration)
                .font(.caption)
                .lineLimit(1)
                .onChange(of: useInfiniteDuration) { _, enabled in
                    if enabled {
                        useCustomDuration = false
                    }
                }

            if useInfiniteDuration {
                Text("Тест будет идти, пока вы не нажмёте «Стоп».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(appState.text(.gameProcessOptional), text: $gameProcessName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    startButtonLocked = true
                    commitCustomDurationText()
                    do {
                        try recorder.start(
                            mode: selectedMode,
                            durationSeconds: durationSeconds,
                            gameProcessName: gameProcessName,
                            selectedChargeLimit: appState.backendStatus.actualUpperLimitPercent ?? appState.selectedLimit.rawValue,
                            selectedLowerLimitDelta: appState.backendStatus.actualLowerLimitDeltaPercent ?? appState.selectedDelta,
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
                    Label(recorder.isRecording ? "Тест идёт" : appState.text(.startTest), systemImage: recorder.isRecording ? "record.circle" : "play.fill")
                }
                .disabled(recorder.isRecording || startButtonLocked)
                .opacity(recorder.isRecording ? 0.55 : 1.0)

                Button {
                    recorder.stop(save: true)
                } label: {
                    Label(recorder.isRecording ? appState.text(.stopTest) : "Тест остановлен", systemImage: recorder.isRecording ? "stop.fill" : "checkmark.circle")
                }
                .disabled(!recorder.isRecording)
                .opacity(recorder.isRecording ? 1.0 : 0.55)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Label(recorder.isRecording ? "Тест сейчас идёт" : "Тест остановлен", systemImage: recorder.isRecording ? "record.circle" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(recorder.isRecording ? .green : .secondary)

            GlassCard(appState.text(.liveMetrics)) {
                VStack(spacing: 5) {
                    StatusRow(title: appState.text(.samples), value: "\(recorder.samples.count)")
                    if let last = recorder.samples.last {
                        StatusRow(title: appState.text(.elapsed), value: String(format: "%.0f s", last.elapsedSeconds))
                        StatusRow(title: appState.text(.battery), value: last.batteryPercent.map { "\($0)%" } ?? appState.text(.unknown))
                        StatusRow(title: appState.text(.batteryPower), value: last.batteryPowerWatts.map { String(format: "%.2f W", $0) } ?? appState.text(.unknown))
                        StatusRow(title: appState.text(.current), value: last.currentMilliamps.map { String(format: "%.0f mA", $0) } ?? appState.text(.unknown))
                        StatusRow(title: appState.text(.actualGuardActive), value: appState.text(last.actualGuardActive == true ? .active : .inactive))
                    } else {
                        StatusRow(title: appState.text(.elapsed), value: "-")
                        StatusRow(title: appState.text(.battery), value: "-")
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
                    Label(appState.text(.compareTests), systemImage: "chart.bar.xaxis")
                }

                Button {
                    openExportFolder()
                } label: {
                    Label(appState.text(.exportCSVJSON), systemImage: "folder")
                }
                .disabled(recorder.lastCSVURL == nil && recorder.lastJSONURL == nil)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            if let error = recorder.lastError {
                Label(appState.text(.unavailable), systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .help(error)
            }

            if let comparison = recorder.lastComparison {
                comparisonCard(comparison)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparisonCard(_ comparison: BatteryLabComparison) -> some View {
        GlassCard(appState.text(.comparison)) {
            if let reduction = comparison.participationReductionPercent {
                Text(String(format: "%.1f%% %@", reduction, appState.text(.lessBatteryParticipation)))
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            Text(String(
                format: "%.2f Wh %@ %.2f Wh",
                comparison.normalReport.batteryThroughputWh,
                appState.text(.versus),
                comparison.guardedReport.batteryThroughputWh
            ))
            .font(.subheadline)
            .fontWeight(.semibold)

            VStack(spacing: 5) {
                StatusRow(title: "\(modeText(comparison.normalReport.testMode)) \(appState.text(.throughput))", value: String(format: "%.6f Wh", comparison.normalReport.batteryThroughputWh))
                StatusRow(title: "AC Guard \(appState.text(.throughput))", value: String(format: "%.6f Wh", comparison.guardedReport.batteryThroughputWh))
                StatusRow(title: appState.text(.reduction), value: comparison.participationReductionPercent.map { String(format: "%.2f%%", $0) } ?? appState.text(.unavailable))
                if let minimum = comparison.guardedReport.observedBatteryMinimumPercent,
                   let maximum = comparison.guardedReport.observedBatteryMaximumPercent {
                    StatusRow(title: appState.text(.observedRange), value: "\(minimum)–\(maximum)%")
                }
            }
        }
    }

    private func modeText(_ mode: BatteryLabMode) -> String {
        switch mode {
        case .batteryOnlyGameTest: appState.text(.batteryOnly)
        case .normalChargingGameTest: appState.text(.normalCharging)
        case .acGuardGameTest: appState.text(.acGuardMode)
        }
    }

    private func commitCustomDurationText() {
        let parsed = Int(customDurationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? customDurationMinutes
        let clamped = min(max(parsed, 1), 720)
        customDurationMinutes = clamped
        customDurationText = "\(clamped)"
    }

    private func openExportFolder() {
        if let csv = recorder.lastCSVURL {
            NSWorkspace.shared.activateFileViewerSelecting([csv])
        } else if let json = recorder.lastJSONURL {
            NSWorkspace.shared.activateFileViewerSelecting([json])
        }
    }
}
