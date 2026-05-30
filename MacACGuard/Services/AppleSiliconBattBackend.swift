import Foundation

final class AppleSiliconBattBackend: ChargeLimitController {
    private let runner: ShellCommandRunner
    private let parser = BattStatusParser()
    private let battExecutable: String
    private let homebrewInstallationDetected: Bool
    private let localWriteBackend: LocalBattBackend
    private let helperBackend: PrivilegedHelperBackend

    init(
        runner: ShellCommandRunner = ShellCommandRunner(),
        helperClient: PrivilegedHelperClient = PackagedPrivilegedHelperClient()
    ) {
        self.runner = runner
        let detectedPath = Self.detectBattPath(runner: runner)
        self.battExecutable = detectedPath ?? "batt"
        self.homebrewInstallationDetected = detectedPath?.contains("/homebrew/") == true || detectedPath?.contains("/usr/local/bin/batt") == true
        self.localWriteBackend = LocalBattBackend(runner: runner, battExecutable: detectedPath ?? "batt")
        self.helperBackend = PrivilegedHelperBackend(client: helperClient)
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

    func getWriteAccess() -> ChargeWriteAccess {
        helperBackend.isAvailable() ? helperBackend.getWriteAccess() : localWriteBackend.getWriteAccess()
    }

    func setChargeLimit(percent: Int) throws {
        try validateLimit(percent)
        if helperBackend.isAvailable() {
            try helperBackend.setChargeLimit(percent: percent)
        } else {
            try localWriteBackend.setChargeLimit(percent: percent)
        }
    }

    func setLowerLimitDelta(percent: Int) throws {
        try validateDelta(percent)
        if helperBackend.isAvailable() {
            try helperBackend.setLowerLimitDelta(percent: percent)
        } else {
            try localWriteBackend.setLowerLimitDelta(percent: percent)
        }
    }

    func enableAdapter() throws {
        if helperBackend.isAvailable() {
            try helperBackend.enableAdapter()
        } else {
            try localWriteBackend.enableAdapter()
        }
    }

    func disableChargeLimit() throws {
        if helperBackend.isAvailable() {
            try helperBackend.disableChargeLimit()
        } else {
            try localWriteBackend.disableLimit()
        }
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

    private func friendlyError(from result: ShellCommandResult) -> String {
        let combined = (result.stderr + "\n" + result.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.isEmpty {
            return "Command exited with code \(result.exitCode)."
        }
        if combined.localizedCaseInsensitiveContains("command not found") ||
            combined.localizedCaseInsensitiveContains("no such file") {
            return "batt is not installed or is not in PATH."
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
