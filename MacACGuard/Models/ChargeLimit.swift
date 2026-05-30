import Foundation

enum ChargeLimitPreset: Int, Codable, CaseIterable, Identifiable {
    case extremeReserve = 30
    case lowReserve = 40
    case longevity = 50
    case recommendedNetwork = 60
    case gamingNetwork = 70
    case softProtection = 80

    var id: Int { rawValue }

    var shortLabel: String {
        "\(rawValue)%"
    }

}

struct ChargeBackendStatus: Codable, Equatable {
    var backendName: String
    var isAvailable: Bool
    var isMonitorOnly: Bool
    var currentLimit: Int?
    var lowerLimitDelta: Int?
    var requiresPrivileges: Bool
    var details: String
    var lastError: String?
    var actualUpperLimitPercent: Int? = nil
    var actualLowerLimitPercent: Int? = nil
    var actualLowerLimitDeltaPercent: Int? = nil
    var battDisabled: Bool = false
    var allowCharging: Bool? = nil
    var usePowerAdapter: Bool? = nil
    var currentChargePercent: Int? = nil
    var batteryStateText: String? = nil
    var chargeRateWatts: Double? = nil
    var voltageVolts: Double? = nil
    var allowNonRootUsers: Bool? = nil
    var rawStatusText: String? = nil
    var battPath: String? = nil
    var homebrewInstallationDetected: Bool = false
    var warning: String? = nil

    static let unknown = ChargeBackendStatus(
        backendName: "Unknown",
        isAvailable: false,
        isMonitorOnly: true,
        currentLimit: nil,
        lowerLimitDelta: nil,
        requiresPrivileges: false,
        details: "Backend has not been detected yet.",
        lastError: nil
    )
}

enum ChargeLimitError: LocalizedError, Equatable {
    case backendUnavailable(String)
    case invalidLimit(Int)
    case invalidDelta(Int)
    case commandFailed(String)
    case privilegesRequired(String)
    case helperUnavailable(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .backendUnavailable(let message):
            message
        case .invalidLimit(let limit):
            "Unsupported charge limit: \(limit)%."
        case .invalidDelta(let delta):
            "Unsupported lower-limit delta: \(delta)%."
        case .commandFailed(let message):
            message
        case .privilegesRequired(let message):
            message
        case .helperUnavailable(let message):
            message
        case .unsupported(let message):
            message
        }
    }
}
