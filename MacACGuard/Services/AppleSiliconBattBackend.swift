import Foundation

final class AppleSiliconBattBackend: ChargeLimitController {
    private let runner: ShellCommandRunner
    private let parser = BattStatusParser()
    private let battExecutable: String
    private let homebrewInstallationDetected: Bool

    init(runner: ShellCommandRunner = ShellCommandRunner()) {
        self.runner = runner
        let detectedPath = Self.detectBattPath(runner: runner)
        self.battExecutable = detectedPath ?? "batt"
        self.homebrewInstallationDetected = detectedPath?.contains("/homebrew/") == true || detectedPath?.contains("/usr/local/bin/batt") == true
    }

    func isAvailable() -> Bool {
        guard let result = try? runBatt(arguments: ["status"], timeout: 5) else {
            return false
        }
        return result.succeeded
    }

    func getBackendName() -> String {
        "batt (Apple Silicon)"
    }

    func getCurrentLimit() -> Int? {
        guard let status = try? runBatt(arguments: ["status"], timeout: 5) else {
            return nil
        }
        let parsed = parser.parse(
            status.stdout + "\n" + status.stderr,
            backendName: getBackendName(),
            battPath: battPath,
            homebrewInstallationDetected: homebrewInstallationDetected
        )
        return parsed.actualUpperLimitPercent
    }

    func setChargeLimit(percent: Int) throws {
        try validateLimit(percent)
        let result = try runner.run(
            executable: "/usr/bin/sudo",
            arguments: ["-n", battExecutable, "limit", "\(percent)"],
            timeout: 20
        )
        try validateBattResult(result, action: "set charge limit to \(percent)%")
    }

    func setLowerLimitDelta(percent: Int) throws {
        guard [2, 5, 10].contains(percent) else {
            throw ChargeLimitError.invalidLimit(percent)
        }
        let result = try runner.run(
            executable: "/usr/bin/sudo",
            arguments: ["-n", battExecutable, "lower-limit-delta", "\(percent)"],
            timeout: 20
        )
        try validateBattResult(result, action: "set lower-limit-delta to \(percent)%")
    }

    func disableChargeLimit() throws {
        let result = try runner.run(
            executable: "/usr/bin/sudo",
            arguments: ["-n", battExecutable, "limit", "100"],
            timeout: 20
        )
        try validateBattResult(result, action: "disable charge limit by setting 100%")
    }

    func getStatus() throws -> ChargeBackendStatus {
        let result = try runBatt(arguments: ["status"], timeout: 5)
        if result.succeeded {
            let combined = result.stdout + "\n" + result.stderr
            return parser.parse(
                combined,
                backendName: getBackendName(),
                battPath: battPath,
                homebrewInstallationDetected: homebrewInstallationDetected
            )
        }

        return ChargeBackendStatus(
            backendName: getBackendName(),
            isAvailable: false,
            isMonitorOnly: true,
            currentLimit: nil,
            lowerLimitDelta: nil,
            requiresPrivileges: true,
            details: "batt is installed but status failed.",
            lastError: friendlyError(from: result),
            battPath: battPath,
            homebrewInstallationDetected: homebrewInstallationDetected
        )
    }

    private var battPath: String? {
        battExecutable == "batt" ? nil : battExecutable
    }

    private func runBatt(arguments: [String], timeout: TimeInterval) throws -> ShellCommandResult {
        if battExecutable.hasPrefix("/") {
            return try runner.run(executable: battExecutable, arguments: arguments, timeout: timeout)
        }
        return try runner.run(executable: "/usr/bin/env", arguments: [battExecutable] + arguments, timeout: timeout)
    }

    private func validateBattResult(_ result: ShellCommandResult, action: String) throws {
        guard result.succeeded else {
            let message = friendlyError(from: result)
            if message.localizedCaseInsensitiveContains("password") ||
                message.localizedCaseInsensitiveContains("sudo") ||
                message.localizedCaseInsensitiveContains("privilege") {
                throw ChargeLimitError.privilegesRequired("Cannot \(action): \(message). Mac AC Guard does not store passwords. Configure batt/daemon or run the command manually once.")
            }
            throw ChargeLimitError.commandFailed("Cannot \(action): \(message)")
        }
    }

    private func friendlyError(from result: ShellCommandResult) -> String {
        let combined = (result.stderr + "\n" + result.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.isEmpty {
            return "Command exited with code \(result.exitCode)."
        }
        if combined.localizedCaseInsensitiveContains("command not found") ||
            combined.localizedCaseInsensitiveContains("no such file") {
            return "batt is not installed or is not in PATH."
        }
        if combined.localizedCaseInsensitiveContains("a password is required") ||
            combined.localizedCaseInsensitiveContains("sorry, try again") {
            return "sudo requires authentication."
        }
        if combined.localizedCaseInsensitiveContains("daemon") {
            return "batt daemon is not running or not configured."
        }
        return combined
    }

    private static func detectBattPath(runner: ShellCommandRunner) -> String? {
        let fileManager = FileManager.default
        for candidate in ["/opt/homebrew/bin/batt", "/usr/local/bin/batt"] where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }
        if let result = try? runner.run(executable: "/usr/bin/which", arguments: ["batt"], timeout: 3),
           result.succeeded {
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        }
        return nil
    }
}
