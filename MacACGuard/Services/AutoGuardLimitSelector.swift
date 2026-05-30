import Foundation

struct AutoGuardLimitSelector {
    static let defaultDelta = 5

    static func limit(for batteryPercent: Int) -> ChargeLimitPreset {
        switch batteryPercent {
        case ...30: .extremeReserve
        case 31...40: .lowReserve
        case 41...50: .longevity
        case 51...60: .recommendedNetwork
        case 61...70: .gamingNetwork
        default: .softProtection
        }
    }
}

enum RequestedGuardMode: String {
    case none
    case auto
    case manual
}

enum GuardStopReason: String {
    case adapterDisconnected
}

enum UserNotice: Equatable {
    case connectAdapter
    case permissionRequired
    case failedApplyLimit
    case configuredCheckingPower
    case adapterDisconnectedStopped
    case adapterConnectedEnableAgain
    case reserveBelowSafe
    case adapterInsufficient
    case monitorOnly

    var localizationKey: L10nKey {
        switch self {
        case .connectAdapter: .connectAdapter
        case .permissionRequired: .permissionRequired
        case .failedApplyLimit: .failedApplyLimit
        case .configuredCheckingPower: .configuredCheckingPower
        case .adapterDisconnectedStopped: .adapterDisconnectedStopped
        case .adapterConnectedEnableAgain: .adapterConnectedEnableAgain
        case .reserveBelowSafe: .reserveBelowSafe
        case .adapterInsufficient: .adapterInsufficient
        case .monitorOnly: .monitorOnly
        }
    }
}
