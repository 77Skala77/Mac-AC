import Foundation

enum PowerSourceType: String, Codable, CaseIterable, Identifiable {
    case ac = "AC"
    case battery = "Battery"
    case unknown = "Unknown"

    var id: String { rawValue }

}

struct BatterySnapshot: Codable, Equatable, Identifiable {
    var id: Date { timestamp }

    var timestamp: Date
    var batteryPercent: Int?
    var isACConnected: Bool
    var powerSourceType: PowerSourceType
    var isCharging: Bool
    var isCharged: Bool
    var currentCapacity: Int?
    var maxCapacity: Int?
    var designCapacity: Int?
    var cycleCount: Int?
    var batteryHealth: String?
    var voltageMillivolts: Double?
    var amperageMilliamps: Double?
    var batteryTemperatureCelsius: Double?
    var adapterWatts: Double?
    var notes: [String]

    init(
        timestamp: Date = Date(),
        batteryPercent: Int? = nil,
        isACConnected: Bool = false,
        powerSourceType: PowerSourceType = .unknown,
        isCharging: Bool = false,
        isCharged: Bool = false,
        currentCapacity: Int? = nil,
        maxCapacity: Int? = nil,
        designCapacity: Int? = nil,
        cycleCount: Int? = nil,
        batteryHealth: String? = nil,
        voltageMillivolts: Double? = nil,
        amperageMilliamps: Double? = nil,
        batteryTemperatureCelsius: Double? = nil,
        adapterWatts: Double? = nil,
        notes: [String] = []
    ) {
        self.timestamp = timestamp
        self.batteryPercent = batteryPercent
        self.isACConnected = isACConnected
        self.powerSourceType = powerSourceType
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.designCapacity = designCapacity
        self.cycleCount = cycleCount
        self.batteryHealth = batteryHealth
        self.voltageMillivolts = voltageMillivolts
        self.amperageMilliamps = amperageMilliamps
        self.batteryTemperatureCelsius = batteryTemperatureCelsius
        self.adapterWatts = adapterWatts
        self.notes = notes
    }

    static let unavailable = BatterySnapshot(notes: ["Power telemetry is unavailable."])

    var voltageVolts: Double? {
        voltageMillivolts.map { $0 / 1_000.0 }
    }

    var currentAmps: Double? {
        amperageMilliamps.map { $0 / 1_000.0 }
    }

    var batteryPowerWatts: Double? {
        guard let voltageVolts, let currentAmps else { return nil }
        return voltageVolts * currentAmps
    }

    var isBatteryDischargingWhileOnAC: Bool {
        guard isACConnected, let amperageMilliamps else { return false }
        return amperageMilliamps < -100
    }
}
