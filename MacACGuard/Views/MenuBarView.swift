import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 14) {
            Picker("View", selection: $appState.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch appState.selectedTab {
            case .status:
                MainStatusView()
            case .lab:
                BatteryLabView()
            case .settings:
                SettingsView()
            }

            Divider()

            Text("Mac AC Guard не отключает аккумулятор физически. Он задаёт лимит зарядки, отслеживает участие батареи и помогает MacBook работать преимущественно от адаптера питания.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 440)
    }
}
