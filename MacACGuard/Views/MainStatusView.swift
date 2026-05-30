import SwiftUI

struct MainStatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac AC Guard")
                        .font(.headline)
                    Text(appState.text(topStatusKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: appState.text(topStatusKey),
                    systemImage: topStatusIcon,
                    tone: topStatusTone
                )
            }

            GlassCard {
                Toggle(
                    appState.text(.workFromAdapter),
                    isOn: Binding(
                        get: { appState.isACGuardModeEnabled },
                        set: { enabled in
                            enabled ? appState.enableACMode() : appState.disableACMode()
                        }
                    )
                )
                .font(.body)
                .fontWeight(.semibold)
                .toggleStyle(.switch)

                Text(appState.text(.autoGuardHelper))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 5) {
                StatusRow(title: appState.text(.battery), value: appState.snapshot.batteryPercent.map { "\($0)%" } ?? appState.text(.unknown))
                StatusRow(title: appState.text(.source), value: appState.text(appState.snapshot.isACConnected ? .adapterSource : .batterySource))
                StatusRow(title: appState.text(.limit), value: upperLimitText)
                StatusRow(title: appState.text(.range), value: rangeText)
                StatusRow(title: appState.text(.mode), value: appState.text(modeKey))
            }
            .padding(.horizontal, 2)

            ChargeLimitPickerView()

            if appState.shouldShowPermissionSetup {
                PermissionRequiredCard()
            }

            if let warning = appState.warningMessage {
                WarningBanner(text: warning)
            }
        }
    }

    private var topStatusKey: L10nKey {
        if !appState.snapshot.isACConnected { return .adapterDisconnected }
        if appState.shouldShowPermissionSetup { return .permissionRequired }
        if appState.isACGuardModeEnabled { return .active }
        return .monitoring
    }

    private var topStatusIcon: String {
        if !appState.snapshot.isACConnected { return "powerplug.fill" }
        if appState.shouldShowPermissionSetup { return "lock.shield" }
        return appState.isACGuardModeEnabled ? "bolt.shield.fill" : "eye"
    }

    private var topStatusTone: StatusTone {
        if !appState.snapshot.isACConnected || appState.shouldShowPermissionSetup { return .warning }
        return appState.isACGuardModeEnabled ? .success : .neutral
    }

    private var modeKey: L10nKey {
        if appState.shouldShowPermissionSetup { return .permissionRequired }
        if appState.isACGuardModeEnabled { return .active }
        return .inactive
    }

    private var upperLimitText: String {
        if appState.backendStatus.battDisabled { return "100%" }
        return appState.backendStatus.actualUpperLimitPercent.map { "\($0)%" }
            ?? appState.lastAutoSelectedLimit.map { "\($0.rawValue)%" }
            ?? appState.text(.unknown)
    }

    private var rangeText: String {
        if let lower = appState.backendStatus.actualLowerLimitPercent,
           let upper = appState.backendStatus.actualUpperLimitPercent {
            return "\(lower)–\(upper)%"
        }
        if let upper = appState.lastAutoSelectedLimit?.rawValue,
           let delta = appState.lastAutoSelectedDelta {
            return "\(upper - delta)–\(upper)%"
        }
        return appState.text(.unknown)
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
