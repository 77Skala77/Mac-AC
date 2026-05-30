import Foundation

struct BatteryLabReport: Codable, Identifiable, Equatable {
    var id: UUID { testId }

    var testId: UUID
    var testMode: BatteryLabMode
    var startedAt: Date
    var finishedAt: Date
    var sampleCount: Int
    var startingBatteryPercent: Int?
    var finalBatteryPercent: Int?
    var batteryPercentDelta: Int?
    var batteryEnergyInWh: Double
    var batteryEnergyOutWh: Double
    var batteryThroughputWh: Double
    var netBatteryChangeWh: Double
    var drainRatePercentPerHour: Double?
    var maxBatteryTemperatureCelsius: Double?
    var avgBatteryPowerWatts: Double?
    var avgCurrentMilliamps: Double?
    var batteryParticipationIndexWh: Double
    var reductionPercentComparedToBaseline: Double?
    var actualChargeUpperLimitPercent: Int?
    var actualChargeLowerLimitPercent: Int?
    var actualChargeDeltaPercent: Int?
    var battDisabled: Bool?
    var uiModeActive: Bool?
    var actualGuardActive: Bool?
    var observedBatteryMinimumPercent: Int? = nil
    var observedBatteryMaximumPercent: Int? = nil
    var qualityLabel: BatteryLabQualityLabel? = nil
    var qualityNotes: [String]? = nil
    var errors: [String]
}

enum BatteryLabQualityLabel: String, Codable, Equatable {
    case clean = "Clean"
    case informative = "Informative"
    case dirty = "Dirty"
}

struct BatteryLabExportBundle: Codable {
    var test: BatteryLabTest
    var samples: [BatteryLabSample]
    var report: BatteryLabReport
}

struct BatteryLabComparison: Codable, Equatable {
    var normalReport: BatteryLabReport
    var guardedReport: BatteryLabReport
    var participationReductionPercent: Double?
    var interpretation: String
    var baselineTitle: String?
    var guardedLimitResult: String?
    var summary: String?
}
