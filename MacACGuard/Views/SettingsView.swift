import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            GroupBox("Backend") {
                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(title: "Name", value: appState.backendStatus.backendName)
                    StatusRow(title: "Available", value: appState.backendStatus.isAvailable ? "Yes" : "No")
                    StatusRow(title: "Privileges", value: appState.backendStatus.requiresPrivileges ? "Required for writes" : "Not required")
                    StatusRow(title: "batt path", value: appState.backendStatus.battPath ?? "Unknown")
                    StatusRow(title: "Homebrew batt", value: appState.backendStatus.homebrewInstallationDetected ? "Yes" : "No")
                    StatusRow(title: "batt disabled", value: String(appState.backendStatus.battDisabled))
                    StatusRow(title: "Actual upper", value: appState.backendStatus.actualUpperLimitPercent.map { "\($0)%" } ?? "Unknown")
                    StatusRow(title: "Actual lower", value: appState.backendStatus.actualLowerLimitPercent.map { "\($0)%" } ?? "Unknown")
                    StatusRow(title: "Actual delta", value: appState.backendStatus.actualLowerLimitDeltaPercent.map { "\($0)%" } ?? "Unknown")
                    StatusRow(title: "Allow charging", value: appState.backendStatus.allowCharging.map(String.init) ?? "Unknown")
                    StatusRow(title: "Use power adapter", value: appState.backendStatus.usePowerAdapter.map(String.init) ?? "Unknown")
                    StatusRow(title: "Allow non-root", value: appState.backendStatus.allowNonRootUsers.map(String.init) ?? "Unknown")
                    StatusRow(title: "App support", value: AppPaths.applicationSupportDirectory.path)
                    StatusRow(title: "Battery Lab exports", value: AppPaths.batteryLabDirectory.path)
                    if let warning = appState.backendStatus.warning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(appState.backendStatus.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error = appState.backendStatus.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }

            DisclosureGroup("Raw batt status") {
                ScrollView {
                    Text(appState.backendStatus.rawStatusText ?? "No raw batt status available.")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }

            GroupBox("Safety") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No SIP disabling.", systemImage: "checkmark.shield")
                    Label("No SMC/firmware mutation in the MVP.", systemImage: "checkmark.shield")
                    Label("No password storage or custom sudo prompt.", systemImage: "checkmark.shield")
                    Label("If batt is unavailable, the app stays in monitor-only mode.", systemImage: "eye")
                }
                .font(.caption)
            }

            Text("For Apple Silicon writes, install and configure batt first. Mac AC Guard calls `sudo -n batt limit <percent>` and `sudo -n batt lower-limit-delta <delta>`; if sudo needs a password, the command fails with a readable error.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
