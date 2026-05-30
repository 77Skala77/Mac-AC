import Foundation

final class BackendDetector {
    private let runner: ShellCommandRunner

    init(runner: ShellCommandRunner = ShellCommandRunner()) {
        self.runner = runner
    }

    func detect() -> ChargeLimitController {
        let architecture = currentArchitecture()
        switch architecture {
        case "arm64":
            let batt = AppleSiliconBattBackend(runner: runner)
            if batt.isAvailable() {
                return batt
            }
            return MonitorOnlyFallbackBackend(reason: "batt is not installed, batt status failed, or batt daemon is unavailable.")
        case "x86_64":
            let intel = IntelSMCBackend()
            if intel.isAvailable() {
                return intel
            }
            return MonitorOnlyFallbackBackend(reason: "Safe Intel SMC/BCLM charge-limit control is not available in this MVP.")
        default:
            return MonitorOnlyFallbackBackend(reason: "Unsupported architecture: \(architecture).")
        }
    }

    func currentArchitecture() -> String {
        if let result = try? runner.run(executable: "/usr/bin/uname", arguments: ["-m"], timeout: 3),
           result.succeeded {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "unknown"
    }
}
