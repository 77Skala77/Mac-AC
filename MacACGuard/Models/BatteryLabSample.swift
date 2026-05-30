import Foundation

struct BatteryLabSample: Codable, Identifiable, Equatable {
    var id: UUID
    var timestamp: Date
    var testId: UUID
    var testMode: BatteryLabMode
    var elapsedSeconds: TimeInterval
    var batteryPercent: Int?
    var currentCapacity: Int?
    var maxCapacity: Int?
    var designCapacity: Int?
    var cycleCount: Int?
    var isACConnected: Bool
    var powerSourceType: PowerSourceType
    var isCharging: Bool
    var voltageMillivolts: Double?
    var currentMilliamps: Double?
    var batteryPowerWatts: Double?
    var batteryTemperatureCelsius: Double?
    var adapterWatts: Double?
    var selectedChargeLimit: Int?
    var selectedLowerLimitDelta: Int?
    var selectedChargeLimitPercent: Int?
    var selectedLowerLimitDeltaPercent: Int?
    var actualChargeUpperLimitPercent: Int?
    var actualChargeLowerLimitPercent: Int?
    var actualChargeDeltaPercent: Int?
    var battDisabled: Bool?
    var backendName: String
    var appModeActive: Bool
    var uiModeActive: Bool?
    var actualGuardActive: Bool?
    var cpuLoad: Double?
    var gpuLoad: Double?
    var gameProcessName: String?
    var gameProcessCPU: Double?
    var notes: String?

    init(
        id: UUID = UUID(),
        test: BatteryLabTest,
        snapshot: BatterySnapshot,
        elapsedSeconds: TimeInterval,
        appModeActive: Bool,
        backendStatus: ChargeBackendStatus? = nil,
        actualGuardActive: Bool? = nil,
        cpuLoad: Double? = nil,
        gpuLoad: Double? = nil,
        gameProcessCPU: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.timestamp = snapshot.timestamp
        self.testId = test.id
        self.testMode = test.mode
        self.elapsedSeconds = elapsedSeconds
        self.batteryPercent = snapshot.batteryPercent
        self.currentCapacity = snapshot.currentCapacity
        self.maxCapacity = snapshot.maxCapacity
        self.designCapacity = snapshot.designCapacity
        self.cycleCount = snapshot.cycleCount
        self.isACConnected = snapshot.isACConnected
        self.powerSourceType = snapshot.powerSourceType
        self.isCharging = snapshot.isCharging
        self.voltageMillivolts = snapshot.voltageMillivolts
        self.currentMilliamps = snapshot.amperageMilliamps
        self.batteryPowerWatts = snapshot.batteryPowerWatts
        self.batteryTemperatureCelsius = snapshot.batteryTemperatureCelsius
        self.adapterWatts = snapshot.adapterWatts
        self.selectedChargeLimit = test.selectedChargeLimit
        self.selectedLowerLimitDelta = test.selectedLowerLimitDelta
        self.selectedChargeLimitPercent = test.selectedChargeLimit
        self.selectedLowerLimitDeltaPercent = test.selectedLowerLimitDelta
        self.actualChargeUpperLimitPercent = backendStatus?.actualUpperLimitPercent
        self.actualChargeLowerLimitPercent = backendStatus?.actualLowerLimitPercent
        self.actualChargeDeltaPercent = backendStatus?.actualLowerLimitDeltaPercent
        self.battDisabled = backendStatus?.battDisabled
        self.backendName = test.backendName
        self.appModeActive = appModeActive
        self.uiModeActive = appModeActive
        self.actualGuardActive = actualGuardActive
        self.cpuLoad = cpuLoad
        self.gpuLoad = gpuLoad
        self.gameProcessName = test.gameProcessName
        self.gameProcessCPU = gameProcessCPU
        self.notes = notes
    }
}
