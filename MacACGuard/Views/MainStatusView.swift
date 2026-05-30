import SwiftUI

struct MainStatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mac AC Guard")
                        .font(.headline)
                    Text(appState.isACGuardModeEnabled ? "Работа от сети активна" : appState.isACGuardSuspended ? "Режим приостановлен" : "Мониторинг")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: appState.snapshot.isACConnected ? "powerplug.fill" : "battery.75percent")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }

            GroupBox {
                VStack(spacing: 8) {
                    StatusRow(title: "Power", value: appState.snapshot.isACConnected ? "AC Connected" : "Battery")
                    StatusRow(title: "Battery", value: appState.snapshot.batteryPercent.map { "\($0)%" } ?? "Unknown")
                    StatusRow(title: "Charging", value: appState.snapshot.isCharging ? "Charging" : appState.snapshot.isCharged ? "Charged" : "Not charging")
                    StatusRow(title: "Source", value: appState.snapshot.powerSourceType.displayName)
                    StatusRow(title: "Backend", value: appState.backendStatus.backendName)
                    StatusRow(title: "Backend status", value: appState.backendStatus.isAvailable ? "Available" : "Monitor only")
                    StatusRow(title: "Actual limit", value: actualLimitText)
                    StatusRow(title: "Actual guard", value: appState.actualGuardActive ? "Active" : "Inactive")
                    if let current = appState.snapshot.amperageMilliamps {
                        StatusRow(title: "Battery current", value: String(format: "%.0f mA", current))
                    }
                    if let power = appState.snapshot.batteryPowerWatts {
                        StatusRow(title: "Battery power", value: String(format: "%.2f W", power))
                    }
                    if let watts = appState.snapshot.adapterWatts {
                        StatusRow(title: "Adapter", value: String(format: "%.0f W", watts))
                    }
                }
            }

            Toggle(
                "Работа от сети",
                isOn: Binding(
                    get: { appState.isACGuardModeEnabled },
                    set: { enabled in
                        if enabled {
                            appState.enableACMode()
                        } else {
                            appState.disableACMode()
                        }
                    }
                )
            )
            .toggleStyle(.switch)

            ChargeLimitPickerView()

            if let warning = appState.warningMessage {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let warning = appState.backendStatus.warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = appState.lastError {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if appState.backendStatus.isMonitorOnly {
                Label("На этом Mac доступен только мониторинг. Управление лимитом зарядки недоступно безопасным способом.", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actualLimitText: String {
        if appState.backendStatus.battDisabled {
            return "batt disabled / limit 100%"
        }
        guard let upper = appState.backendStatus.actualUpperLimitPercent else {
            return "actual limit unknown"
        }
        if let lower = appState.backendStatus.actualLowerLimitPercent {
            return "\(lower)-\(upper)%"
        }
        return "\(upper)%"
    }
}

struct StatusRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.caption)
    }
}
