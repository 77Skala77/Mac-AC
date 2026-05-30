import Foundation
import IOKit
import IOKit.ps

final class PowerSourceMonitor {
    private let runner: ShellCommandRunner

    init(runner: ShellCommandRunner = ShellCommandRunner()) {
        self.runner = runner
    }

    func snapshot() -> BatterySnapshot {
        var snapshot = iokitPowerSourceSnapshot() ?? .unavailable
        let registry = smartBatteryProperties()
        applyRegistry(registry, to: &snapshot)

        if snapshot.batteryPercent == nil {
            applyPMSetFallback(to: &snapshot)
        }

        return snapshot
    }

    private func iokitPowerSourceSnapshot() -> BatterySnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        var notes: [String] = []
        var selectedDescription: [String: Any]?

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let type = description[kIOPSTypeKey as String] as? String,
               type == kIOPSInternalBatteryType {
                selectedDescription = description
                break
            }
            selectedDescription = selectedDescription ?? description
        }

        guard let description = selectedDescription else {
            return nil
        }

        let currentCapacity = intValue(description[kIOPSCurrentCapacityKey as String])
        let maxCapacity = intValue(description[kIOPSMaxCapacityKey as String])
        let percent: Int?
        if let currentCapacity, let maxCapacity, maxCapacity > 0 {
            percent = Int((Double(currentCapacity) / Double(maxCapacity) * 100.0).rounded())
        } else {
            percent = nil
            notes.append("Battery percentage unavailable from IOKit.")
        }

        let sourceState = description[kIOPSPowerSourceStateKey as String] as? String
        let powerSourceType: PowerSourceType
        if sourceState == kIOPSACPowerValue {
            powerSourceType = .ac
        } else if sourceState == kIOPSBatteryPowerValue {
            powerSourceType = .battery
        } else {
            powerSourceType = .unknown
        }

        return BatterySnapshot(
            batteryPercent: percent,
            isACConnected: powerSourceType == .ac,
            powerSourceType: powerSourceType,
            isCharging: boolValue(description[kIOPSIsChargingKey as String]) ?? false,
            isCharged: boolValue(description[kIOPSIsChargedKey as String]) ?? false,
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            notes: notes
        )
    }

    private func smartBatteryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return dictionary
    }

    private func applyRegistry(_ properties: [String: Any], to snapshot: inout BatterySnapshot) {
        guard !properties.isEmpty else {
            snapshot.notes.append("AppleSmartBattery IORegistry properties unavailable.")
            return
        }

        snapshot.currentCapacity = snapshot.currentCapacity ?? intValue(properties["AppleRawCurrentCapacity"]) ?? intValue(properties["CurrentCapacity"])
        snapshot.maxCapacity = snapshot.maxCapacity ?? intValue(properties["AppleRawMaxCapacity"]) ?? intValue(properties["MaxCapacity"])
        snapshot.designCapacity = intValue(properties["DesignCapacity"]) ?? intValue((properties["BatteryData"] as? [String: Any])?["DesignCapacity"])
        snapshot.cycleCount = intValue(properties["CycleCount"]) ?? intValue((properties["BatteryData"] as? [String: Any])?["CycleCount"])
        snapshot.voltageMillivolts = doubleValue(properties["Voltage"])
        snapshot.amperageMilliamps = doubleValue(properties["InstantAmperage"]) ?? doubleValue(properties["Amperage"])
        snapshot.batteryTemperatureCelsius = normalizeBatteryTemperature(doubleValue(properties["Temperature"]))
        snapshot.batteryHealth = healthString(from: properties)

        if let externalConnected = boolValue(properties["ExternalConnected"]) {
            snapshot.isACConnected = externalConnected
            if externalConnected, snapshot.powerSourceType == .unknown {
                snapshot.powerSourceType = .ac
            }
        }

        if let isCharging = boolValue(properties["IsCharging"]) {
            snapshot.isCharging = isCharging
        }

        if let adapterDetails = properties["AdapterDetails"] as? [String: Any] {
            snapshot.adapterWatts = doubleValue(adapterDetails["Watts"]) ?? doubleValue(adapterDetails["CurrentWatts"])
        }

        if snapshot.batteryPercent == nil,
           let current = snapshot.currentCapacity,
           let max = snapshot.maxCapacity,
           max > 0 {
            snapshot.batteryPercent = Int((Double(current) / Double(max) * 100.0).rounded())
        }
    }

    private func applyPMSetFallback(to snapshot: inout BatterySnapshot) {
        guard let result = try? runner.run(executable: "/usr/bin/pmset", arguments: ["-g", "batt"], timeout: 5),
              result.succeeded else {
            snapshot.notes.append("pmset fallback unavailable.")
            return
        }

        let text = result.stdout
        if let percent = parsePMSetPercent(text) {
            snapshot.batteryPercent = percent
        }
        if text.localizedCaseInsensitiveContains("AC Power") {
            snapshot.isACConnected = true
            snapshot.powerSourceType = .ac
        } else if text.localizedCaseInsensitiveContains("Battery Power") {
            snapshot.isACConnected = false
            snapshot.powerSourceType = .battery
        }
        snapshot.isCharging = text.localizedCaseInsensitiveContains("charging")
    }

    private func parsePMSetPercent(_ text: String) -> Int? {
        guard let percentRange = text.range(of: "%") else { return nil }
        let prefix = text[..<percentRange.lowerBound]
        let digits = prefix.reversed().prefix { $0.isNumber }.reversed()
        return Int(String(digits))
    }

    private func healthString(from properties: [String: Any]) -> String? {
        if let condition = properties["BatteryHealth"] as? String {
            return condition
        }
        if let condition = properties["BatteryHealthCondition"] as? String {
            return condition
        }
        if let failure = intValue(properties["PermanentFailureStatus"]), failure != 0 {
            return "Service recommended"
        }
        return nil
    }

    private func normalizeBatteryTemperature(_ value: Double?) -> Double? {
        guard let value else { return nil }
        if value > 1_000 {
            return value / 10.0 - 273.15
        }
        if value > 200 {
            return value - 273.15
        }
        return value
    }
}

private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? Int32 { return Int(value) }
    if let value = value as? Int64 { return Int(value) }
    if let value = value as? UInt64 { return Int(value) }
    if let value = value as? Double { return Int(value) }
    if let value = value as? String { return Int(value) }
    return nil
}

private func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Float { return Double(value) }
    if let value = value as? Int { return Double(value) }
    if let value = value as? Int32 { return Double(value) }
    if let value = value as? Int64 { return Double(value) }
    if let value = value as? UInt64 { return Double(value) }
    if let value = value as? String { return Double(value) }
    return nil
}

private func boolValue(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = value as? Int { return value != 0 }
    if let value = value as? String {
        if value == "1" || value.localizedCaseInsensitiveContains("yes") || value.localizedCaseInsensitiveContains("true") {
            return true
        }
        if value == "0" || value.localizedCaseInsensitiveContains("no") || value.localizedCaseInsensitiveContains("false") {
            return false
        }
    }
    return nil
}
