import SwiftUI

enum StatusTone {
    case neutral
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .neutral: .secondary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}

struct GlassPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .background(.regularMaterial)
    }
}

struct GlassCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.10))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatusBadge: View {
    var text: String
    var systemImage: String
    var tone: StatusTone = .neutral

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(tone.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tone.color.opacity(0.11))
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

struct WarningBanner: View {
    var text: String
    var tone: StatusTone = .warning

    var body: some View {
        Label(text, systemImage: tone == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.color.opacity(0.14))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(tone.color.opacity(0.35))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PermissionRequiredCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassCard(appState.text(.permissionSetup)) {
            Label(appState.text(.permissionRequired), systemImage: "lock.shield")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)

            Text(appState.text(.permissionExplanation))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Text(appState.text(.passwordNeverStored) + " " + appState.text(.macOSHandlesAuthorization))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(appState.text(.grantPermission)) {
                    appState.grantPermission()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button(appState.text(.useTerminalSetupInstead)) {
                    appState.useTerminalSetupInstead()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            HStack {
                Button {
                    appState.copySetupCommands()
                } label: {
                    Label(appState.text(.copySetupCommands), systemImage: "doc.on.doc")
                }

                Button {
                    appState.openTerminalInstructions()
                } label: {
                    Label(appState.text(.terminalInstructions), systemImage: "terminal")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                appState.refreshStatus()
            } label: {
                Label(appState.text(.refreshStatus), systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.65 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.regularMaterial.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
