import SwiftUI

struct ChargeLimitPickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Limit", selection: $appState.selectedLimit) {
                ForEach(ChargeLimitPreset.allCases) { preset in
                    Text(preset.shortLabel).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            Text(appState.selectedLimit.displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Delta", selection: $appState.selectedDelta) {
                Text("2").tag(2)
                Text("5").tag(5)
                Text("10").tag(10)
            }
            .pickerStyle(.segmented)

            Text("Hysteresis range: \(max(0, appState.selectedLimit.rawValue - appState.selectedDelta))-\(appState.selectedLimit.rawValue)%")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    appState.applySelectedLimit()
                } label: {
                    Label("Apply Limit", systemImage: "checkmark.circle")
                }

                Button {
                    appState.disableACMode()
                } label: {
                    Label("Disable Limit", systemImage: "xmark.circle")
                }
            }

            HStack {
                Button {
                    appState.refreshStatus()
                } label: {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                }

                Button {
                    appState.selectedTab = .lab
                } label: {
                    Label("Open Battery Lab", systemImage: "waveform.path.ecg")
                }
            }

            Button {
                appState.openLogsFolder()
            } label: {
                Label("Export Logs", systemImage: "square.and.arrow.up")
            }

            if let warning = appState.selectedLimit.warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
