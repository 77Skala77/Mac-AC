import Foundation

struct BattStatusParser {
    func parse(
        _ text: String,
        backendName: String,
        battPath: String?,
        homebrewInstallationDetected: Bool
    ) -> ChargeBackendStatus {
        let upperLimit = parsePercentLine(text, label: "Upper limit")
        let lowerLimit = parsePercentLine(text, label: "Lower limit")
        let disabledLimit = parseDisabledChargeLimit(text)
        let battDisabled = disabledLimit != nil
        let actualUpper = battDisabled ? disabledLimit : upperLimit
        let delta: Int?
        if let upperLimit, let lowerLimit {
            delta = upperLimit - lowerLimit
        } else {
            delta = nil
        }

        let allowNonRootUsers = parseCheckmarkLine(text, label: "Allow non-root users to access the daemon")
        let warning: String?
        if allowNonRootUsers == false {
            warning = "batt daemon is available, but non-root daemon access is disabled. Some write commands may fail depending on installation mode."
        } else {
            warning = nil
        }

        return ChargeBackendStatus(
            backendName: backendName,
            isAvailable: true,
            isMonitorOnly: false,
            currentLimit: actualUpper,
            lowerLimitDelta: delta,
            requiresPrivileges: true,
            details: text.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "batt status is available.",
            lastError: nil,
            actualUpperLimitPercent: actualUpper,
            actualLowerLimitPercent: battDisabled ? nil : lowerLimit,
            actualLowerLimitDeltaPercent: battDisabled ? nil : delta,
            battDisabled: battDisabled,
            allowCharging: parseCheckmarkLine(text, label: "Allow charging"),
            usePowerAdapter: parseCheckmarkLine(text, label: "Use power adapter"),
            currentChargePercent: parsePercentLine(text, label: "Current charge"),
            batteryStateText: parseTextLine(text, label: "State"),
            chargeRateWatts: parseWattsLine(text, label: "Charge rate"),
            voltageVolts: parseVoltsLine(text, label: "Voltage"),
            allowNonRootUsers: allowNonRootUsers,
            rawStatusText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            battPath: battPath,
            homebrewInstallationDetected: homebrewInstallationDetected,
            warning: warning
        )
    }

    private func parseDisabledChargeLimit(_ text: String) -> Int? {
        for line in text.lines {
            let lower = line.lowercased()
            guard lower.contains("charge limit"), lower.contains("batt disabled") else { continue }
            return firstPercent(in: line)
        }
        return nil
    }

    private func parsePercentLine(_ text: String, label: String) -> Int? {
        guard let line = line(in: text, label: label) else { return nil }
        return firstPercent(in: line)
    }

    private func parseCheckmarkLine(_ text: String, label: String) -> Bool? {
        guard let line = line(in: text, label: label) else { return nil }
        if line.contains("✔") { return true }
        if line.contains("✘") { return false }
        let lower = line.lowercased()
        if lower.contains("yes") || lower.contains("true") { return true }
        if lower.contains("no") || lower.contains("false") { return false }
        return nil
    }

    private func parseTextLine(_ text: String, label: String) -> String? {
        guard let line = line(in: text, label: label),
              let range = line.range(of: ":") else {
            return nil
        }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func parseWattsLine(_ text: String, label: String) -> Double? {
        guard let line = line(in: text, label: label) else { return nil }
        return firstSignedDouble(in: line)
    }

    private func parseVoltsLine(_ text: String, label: String) -> Double? {
        guard let line = line(in: text, label: label) else { return nil }
        return firstSignedDouble(in: line)
    }

    private func line(in text: String, label: String) -> String? {
        text.lines.first { line in
            line.trimmingCharacters(in: .whitespaces)
                .range(of: "\(label):", options: [.caseInsensitive, .anchored]) != nil
        }
    }

    private func firstPercent(in text: String) -> Int? {
        guard let percentRange = text.range(of: "%") else { return nil }
        let prefix = text[..<percentRange.lowerBound]
        let digits = prefix.reversed().prefix { $0.isNumber }.reversed()
        return Int(String(digits))
    }

    private func firstSignedDouble(in text: String) -> Double? {
        let pattern = #"[-+]?\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return Double(text[range])
    }
}

private extension String {
    var lines: [String] {
        split(whereSeparator: \.isNewline).map(String.init)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
