import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(appState.text(.settings))
                    .font(.headline)
                Spacer()
                Picker(appState.text(.language), selection: languageBinding) {
                    Text(appState.text(.russian)).tag(AppLanguage.ru)
                    Text(appState.text(.english)).tag(AppLanguage.en)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            GlassCard(appState.text(.diagnostics)) {
                VStack(alignment: .leading, spacing: 5) {
                    StatusRow(title: appState.text(.readBackend), value: appState.backendStatus.backendName)
                    StatusRow(title: appState.text(.writeBackend), value: writeBackendText)
                    StatusRow(title: appState.text(.authorizationState), value: authorizationStateText)
                    StatusRow(title: appState.text(.daemonAvailable), value: yesNo(appState.backendStatus.isAvailable))
                    StatusRow(title: appState.text(.battPath), value: appState.backendStatus.battPath ?? appState.text(.unknown))
                    StatusRow(title: appState.text(.allowNonRoot), value: optionalYesNo(appState.backendStatus.allowNonRootUsers))
                    StatusRow(title: appState.text(.actualGuardActive), value: yesNo(appState.actualGuardActive))
                    StatusRow(title: appState.text(.actualUpper), value: percent(appState.backendStatus.actualUpperLimitPercent))
                    StatusRow(title: appState.text(.actualLower), value: percent(appState.backendStatus.actualLowerLimitPercent))
                    StatusRow(title: appState.text(.actualDelta), value: percent(appState.backendStatus.actualLowerLimitDeltaPercent))
                    StatusRow(title: appState.text(.battDisabled), value: yesNo(appState.backendStatus.battDisabled))
                    StatusRow(title: appState.text(.manualSelectedLimit), value: "\(appState.selectedLimit.rawValue)% / \(appState.selectedDelta)%")
                    StatusRow(title: appState.text(.autoSelectedLimit), value: percent(appState.lastAutoSelectedLimit?.rawValue))
                    StatusRow(title: appState.text(.requestedMode), value: requestedModeText)
                    StatusRow(title: appState.text(.lastAutoLimit), value: percent(appState.lastAutoSelectedLimit?.rawValue))
                    StatusRow(title: appState.text(.lastAutoDelta), value: percent(appState.lastAutoSelectedDelta))
                    StatusRow(title: appState.text(.configuredPending), value: yesNo(appState.configuredPending))
                    StatusRow(title: appState.text(.userRequestedAutoGuard), value: yesNo(appState.userRequestedAutoGuard))
                    StatusRow(title: appState.text(.lastStopReason), value: stopReasonText)
                    StatusRow(title: appState.text(.batteryCurrent), value: appState.snapshot.amperageMilliamps.map { String(format: "%.0f mA", $0) } ?? appState.text(.unknown))
                    StatusRow(title: appState.text(.batteryPower), value: appState.snapshot.batteryPowerWatts.map { String(format: "%.2f W", $0) } ?? appState.text(.unknown))
                    StatusRow(title: appState.text(.adapterLoadAssessment), value: adapterLoadAssessmentText)
                    StatusRow(title: appState.text(.lastBattResponse), value: appState.backendStatus.rawStatusText == nil ? appState.text(.unavailable) : appState.text(.available))
                    StatusRow(title: appState.text(.appSupportDirectory), value: AppPaths.applicationSupportDirectory.path)
                    StatusRow(title: appState.text(.batteryLabDirectory), value: AppPaths.batteryLabDirectory.path)

                    if let error = appState.writeAccess.lastWriteError {
                        diagnosticText("\(appState.text(.lastWriteError)): \(error)", color: .red)
                    }
                    if let warning = appState.backendStatus.warning {
                        diagnosticText(warning, color: .orange)
                    }
                    if let error = appState.lastError {
                        diagnosticText("\(appState.text(.lastWriteError)): \(error)", color: .red)
                    }
                }
            }

            DisclosureGroup(appState.text(.rawBattStatus)) {
                ScrollView {
                    Text(appState.backendStatus.rawStatusText ?? appState.text(.unknown))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }

            GlassCard(appState.text(.safety)) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(appState.text(.noSIP), systemImage: "checkmark.shield")
                    Label(appState.text(.noSMC), systemImage: "checkmark.shield")
                    Label(appState.text(.noPassword), systemImage: "checkmark.shield")
                    Label(appState.text(.monitorFallback), systemImage: "eye")
                }
                .font(.caption)
            }

            Text(appState.text(.backendSetupNote))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { appState.language },
            set: { appState.setLanguage($0) }
        )
    }

    private var requestedModeText: String {
        switch appState.requestedMode {
        case .none: appState.text(.modeNone)
        case .auto: appState.text(.modeAuto)
        case .manual: appState.text(.modeManual)
        }
    }

    private var writeBackendText: String {
        switch appState.writeAccess.backend {
        case .directBatt: appState.text(.directBatt)
        case .privilegedHelper: appState.text(.privilegedHelper)
        case .manualSetupRequired: appState.text(.manualSetupRequired)
        case .monitorOnly: appState.text(.monitorOnlyBackend)
        }
    }

    private var authorizationStateText: String {
        switch appState.writeAccess.authorizationState {
        case .unknown: appState.text(.authorizationUnknown)
        case .notRequired: appState.text(.authorizationNotRequired)
        case .required: appState.text(.authorizationRequired)
        case .authorized: appState.text(.authorizationAuthorized)
        case .denied: appState.text(.authorizationDenied)
        case .helperMissing: appState.text(.helperMissing)
        case .helperNeedsInstall: appState.text(.helperNeedsInstall)
        case .helperOutdated: appState.text(.helperOutdated)
        case .failed(let message): "\(appState.text(.authorizationFailed)): \(message)"
        }
    }

    private var stopReasonText: String {
        switch appState.lastStopReason {
        case .adapterDisconnected: appState.text(.stoppedAdapterDisconnected)
        case nil: appState.text(.unknown)
        }
    }

    private var adapterLoadAssessmentText: String {
        switch appState.adapterLoadAssessment {
        case .stable: appState.text(.stable)
        case .stabilizing: appState.text(.powerStabilizing)
        case .sustainedBatteryDischarge: appState.text(.sustainedBatteryDischarge)
        }
    }

    private func percent(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? appState.text(.unknown)
    }

    private func optionalYesNo(_ value: Bool?) -> String {
        value.map(yesNo) ?? appState.text(.unknown)
    }

    private func yesNo(_ value: Bool) -> String {
        appState.text(value ? .yes : .no)
    }

    private func diagnosticText(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
