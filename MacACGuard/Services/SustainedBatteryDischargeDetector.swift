import Foundation

enum AdapterLoadAssessment: Equatable {
    case stable
    case stabilizing
    case sustainedBatteryDischarge
}

struct SustainedBatteryDischargeDetector {
    static let warningThresholdWatts = -10.0
    static let requiredDuration: TimeInterval = 20

    private struct Sample {
        var timestamp: Date
        var powerWatts: Double
    }

    private var samples: [Sample] = []
    private(set) var averagePowerWatts: Double?

    mutating func evaluate(
        timestamp: Date,
        batteryPowerWatts: Double?,
        isACConnected: Bool,
        isGuardSessionActive: Bool
    ) -> AdapterLoadAssessment {
        guard isACConnected, isGuardSessionActive, let batteryPowerWatts else {
            reset()
            return .stable
        }

        samples.append(Sample(timestamp: timestamp, powerWatts: batteryPowerWatts))
        let cutoff = timestamp.addingTimeInterval(-Self.requiredDuration)
        samples.removeAll { $0.timestamp < cutoff }
        averagePowerWatts = samples.map(\.powerWatts).reduce(0, +) / Double(samples.count)

        guard let first = samples.first else { return .stable }
        let sampledDuration = timestamp.timeIntervalSince(first.timestamp)

        if sampledDuration >= Self.requiredDuration,
           let averagePowerWatts,
           averagePowerWatts < Self.warningThresholdWatts {
            return .sustainedBatteryDischarge
        }

        if let averagePowerWatts,
           averagePowerWatts < Self.warningThresholdWatts {
            return .stabilizing
        }

        return .stable
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        averagePowerWatts = nil
    }
}
