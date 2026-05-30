import Foundation

enum AppEventKind: String, Codable {
    case appStarted
    case backendDetected
    case acConnected
    case acDisconnected
    case modeEnabled
    case modeDisabled
    case limitChanged
    case lowerLimitDeltaChanged
    case adapterEnabled
    case permissionSetupRequired
    case acGuardStoppedAdapterDisconnected
    case batteryStartedDischargingWhileACConnected
    case batteryBelowSafetyThreshold
    case batteryLabTestStarted
    case batteryLabTestFinished
    case duplicateInstance
    case error
}

struct AppEvent: Codable {
    var timestamp: Date
    var kind: AppEventKind
    var message: String
}

final class EventLogger {
    let logURL: URL
    private let encoder = JSONEncoder()

    init(logURL: URL = AppPaths.eventsLogURL) {
        self.logURL = logURL
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    func log(_ kind: AppEventKind, _ message: String) {
        let event = AppEvent(timestamp: Date(), kind: kind, message: message)
        guard let data = try? encoder.encode(event) else { return }
        let line = data + Data("\n".utf8)
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
                try? handle.close()
            }
        } else {
            try? line.write(to: logURL, options: .atomic)
        }
    }

    func flush() {
        // Event writes are synchronous; this keeps the termination API explicit.
    }
}

enum AppPaths {
    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("MacACGuard", isDirectory: true)
    }

    static var batteryLabDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("BatteryLab", isDirectory: true)
    }

    static var eventsLogURL: URL {
        applicationSupportDirectory.appendingPathComponent("events.jsonl")
    }

    static var instanceLockURL: URL {
        applicationSupportDirectory.appendingPathComponent("MacACGuard.lock")
    }
}
