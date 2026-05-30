import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassPanel {
            VStack(spacing: 8) {
                Picker(appState.text(.status), selection: $appState.selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        Text(appState.text(tab.localizationKey)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                ScrollView {
                    switch appState.selectedTab {
                    case .status:
                        MainStatusView()
                    case .lab:
                        BatteryLabView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxHeight: 680)

                Divider()

                Text(appState.text(.physicalDisclaimer))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 410)
        .background(.regularMaterial)
    }
}
