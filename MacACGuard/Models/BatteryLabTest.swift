import Foundation

enum BatteryLabMode: String, Codable, CaseIterable, Identifiable {
    case batteryOnlyGameTest = "BatteryOnlyGameTest"
    case normalChargingGameTest = "NormalChargingGameTest"
    case acGuardGameTest = "ACGuardGameTest"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .batteryOnlyGameTest: "Battery only"
        case .normalChargingGameTest: "Normal charging"
        case .acGuardGameTest: "AC Guard mode"
        }
    }
}

struct BatteryLabTest: Codable, Identifiable, Equatable {
    var id: UUID
    var mode: BatteryLabMode
    var startedAt: Date
    var plannedDurationSeconds: TimeInterval
    var gameProcessName: String?
    var selectedChargeLimit: Int?
    var selectedLowerLimitDelta: Int?
    var backendName: String

    init(
        id: UUID = UUID(),
        mode: BatteryLabMode,
        startedAt: Date = Date(),
        plannedDurationSeconds: TimeInterval,
        gameProcessName: String?,
        selectedChargeLimit: Int?,
        selectedLowerLimitDelta: Int?,
        backendName: String
    ) {
        self.id = id
        self.mode = mode
        self.startedAt = startedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.gameProcessName = gameProcessName?.isEmpty == true ? nil : gameProcessName
        self.selectedChargeLimit = selectedChargeLimit
        self.selectedLowerLimitDelta = selectedLowerLimitDelta
        self.backendName = backendName
    }
}
