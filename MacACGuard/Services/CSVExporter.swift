import Foundation

struct CSVExporter {
    func csv(for samples: [BatteryLabSample]) -> String {
        let header = [
            "timestamp",
            "testId",
            "testMode",
            "elapsedSeconds",
            "batteryPercent",
            "currentCapacity",
            "maxCapacity",
            "designCapacity",
            "cycleCount",
            "isACConnected",
            "powerSourceType",
            "isCharging",
            "voltage_mV",
            "current_mA",
            "batteryPower_W",
            "batteryTemperature_C",
            "adapterWatts",
            "selectedChargeLimit",
            "selectedLowerLimitDelta",
            "selectedChargeLimitPercent",
            "selectedLowerLimitDeltaPercent",
            "actualChargeUpperLimitPercent",
            "actualChargeLowerLimitPercent",
            "actualChargeDeltaPercent",
            "battDisabled",
            "backendName",
            "appModeActive",
            "uiModeActive",
            "actualGuardActive",
            "cpuLoad",
            "gpuLoad",
            "gameProcessName",
            "gameProcessCPU",
            "notes"
        ]

        let rows = samples.map { sample in
            [
                sample.timestamp.ISO8601Format(),
                sample.testId.uuidString,
                sample.testMode.rawValue,
                format(sample.elapsedSeconds),
                format(sample.batteryPercent),
                format(sample.currentCapacity),
                format(sample.maxCapacity),
                format(sample.designCapacity),
                format(sample.cycleCount),
                String(sample.isACConnected),
                sample.powerSourceType.rawValue,
                String(sample.isCharging),
                format(sample.voltageMillivolts),
                format(sample.currentMilliamps),
                format(sample.batteryPowerWatts),
                format(sample.batteryTemperatureCelsius),
                format(sample.adapterWatts),
                format(sample.selectedChargeLimit),
                format(sample.selectedLowerLimitDelta),
                format(sample.selectedChargeLimitPercent),
                format(sample.selectedLowerLimitDeltaPercent),
                format(sample.actualChargeUpperLimitPercent),
                format(sample.actualChargeLowerLimitPercent),
                format(sample.actualChargeDeltaPercent),
                format(sample.battDisabled),
                sample.backendName,
                String(sample.appModeActive),
                format(sample.uiModeActive),
                format(sample.actualGuardActive),
                format(sample.cpuLoad),
                format(sample.gpuLoad),
                sample.gameProcessName ?? "",
                format(sample.gameProcessCPU),
                sample.notes ?? ""
            ].map(escape).joined(separator: ",")
        }

        return ([header.joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
    }

    func write(samples: [BatteryLabSample], to url: URL) throws {
        try csv(for: samples).write(to: url, atomically: true, encoding: .utf8)
    }

    private func format(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.4f", value)
    }

    private func format(_ value: Bool?) -> String {
        value.map(String.init) ?? ""
    }

    private func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
