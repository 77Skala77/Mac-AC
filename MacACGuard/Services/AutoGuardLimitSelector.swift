import Foundation

struct AutoGuardLimitSelector {
    static let minimumAutoLimit = 30
    static let maximumAutoLimit = 80
    static let defaultDelta = 1

    /// Auto Guard keeps the battery near the current charge level with 1% precision,
    /// but clamps the automatic limit to the safe 30–80% range.
    ///
    /// Examples:
    /// - 25% -> 30%
    /// - 29% -> 30%
    /// - 30% -> 30%
    /// - 57% -> 57%
    /// - 71% -> 71%
    /// - 80% -> 80%
    /// - 83% -> 80%
    static func limit(for batteryPercent: Int) -> Int {
        min(max(batteryPercent, minimumAutoLimit), maximumAutoLimit)
    }

    /// Lower limit for batt hysteresis range.
    ///
    /// With defaultDelta = 1:
    /// - 71% -> 70–71%
    /// - 80% -> 79–80%
    /// - 30% -> 29–30%
    static func lowerLimit(for batteryPercent: Int) -> Int {
        max(limit(for: batteryPercent) - defaultDelta, 0)
    }

    static func rangeDescription(for batteryPercent: Int) -> String {
        let upper = limit(for: batteryPercent)
        let lower = lowerLimit(for: batteryPercent)
        return "\(lower)–\(upper)%"
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
