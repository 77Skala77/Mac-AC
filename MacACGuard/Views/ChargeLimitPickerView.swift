import SwiftUI

struct ChargeLimitPickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassCard(appState.text(.manualChargeLimit)) {
            Picker(appState.text(.limit), selection: $appState.selectedLimit) {
                ForEach(ChargeLimitPreset.allCases) { preset in
                    Text(preset.shortLabel).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Text(appState.text(.delta))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(appState.text(.delta), selection: $appState.selectedDelta) {
                    Text("2").tag(2)
                    Text("5").tag(5)
                    Text("10").tag(10)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Text("\(appState.text(.hysteresisRange)): \(max(0, appState.selectedLimit.rawValue - appState.selectedDelta))–\(appState.selectedLimit.rawValue)%")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    appState.applySelectedLimit()
                } label: {
                    Label(appState.text(.applySelectedLimit), systemImage: "checkmark.circle")
                }

                Button {
                    appState.disableACMode()
                } label: {
                    Label(appState.text(.disableLimit), systemImage: "xmark.circle")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())

            HStack {
                Button {
                    appState.refreshStatus()
                } label: {
                    Label(appState.text(.refreshStatus), systemImage: "arrow.clockwise")
                }

                Button {
                    appState.selectedTab = .lab
                } label: {
                    Label(appState.text(.openBatteryLab), systemImage: "waveform.path.ecg")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                appState.openLogsFolder()
            } label: {
                Label(appState.text(.exportLogs), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }
}
