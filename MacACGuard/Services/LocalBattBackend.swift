import Foundation

final class LocalBattBackend {
    private let runner: ShellCommandRunner
    private let battExecutable: String
    private var writeAccess = WriteBackendResolver.select(
        helperAvailable: false,
        directWriteSucceeded: nil,
        statusAvailable: true
    )

    init(runner: ShellCommandRunner, battExecutable: String) {
        self.runner = runner
        self.battExecutable = battExecutable
    }

    func getWriteAccess() -> ChargeWriteAccess {
        writeAccess
    }

    func setChargeLimit(percent: Int) throws {
        guard (5...100).contains(percent) else {
            throw ChargeLimitError.invalidLimit(percent)
        }

        try perform(arguments: ["limit", "\(percent)"], action: "set charge limit to \(percent)%")
    }

    func setLowerLimitDelta(percent: Int) throws {
        guard [1, 2, 5, 10].contains(percent) else {
            throw ChargeLimitError.invalidDelta(percent)
        }

        try perform(arguments: ["lower-limit-delta", "\(percent)"], action: "set lower-limit-delta to \(percent)%")
    }

    func enableAdapter() throws {
        try perform(arguments: ["adapter", "enable"], action: "enable adapter mode")
    }

    func disableLimit() throws {
        try perform(arguments: ["limit", "100"], action: "disable charge limit by setting 100%")
    }

    private func perform(arguments: [String], action: String) throws {
        let result = try runBatt(arguments: arguments, timeout: 20)

        guard result.succeeded else {
            let message = friendlyError(from: result)

            if isAuthorizationError(message) {
                writeAccess = ChargeWriteAccess(
                    backend: .manualSetupRequired,
                    authorizationState: .required,
                    lastWriteError: "Cannot \(action): \(message)"
                )

                throw ChargeLimitError.privilegesRequired(
                    "Cannot \(action): \(message) Mac AC Guard does not store passwords. Grant permission through a signed helper build or use the Terminal setup instructions."
                )
            }

            writeAccess = ChargeWriteAccess(
                backend: .directBatt,
                authorizationState: .failed(message),
                lastWriteError: "Cannot \(action): \(message)"
            )

            throw ChargeLimitError.commandFailed("Cannot \(action): \(message)")
        }

        writeAccess = WriteBackendResolver.select(
            helperAvailable: false,
            directWriteSucceeded: true,
            statusAvailable: true
        )
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

        if combined.localizedCaseInsensitiveContains("permission denied") ||
            combined.localizedCaseInsensitiveContains("not permitted") ||
            combined.localizedCaseInsensitiveContains("root") ||
            combined.localizedCaseInsensitiveContains("password") ||
            combined.localizedCaseInsensitiveContains("sudo") {
            return "batt requires administrator authorization."
        }

        if combined.localizedCaseInsensitiveContains("daemon") {
            return "batt daemon is not running or not configured."
        }

        return combined
    }

    private func isAuthorizationError(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("authorization") ||
            message.localizedCaseInsensitiveContains("permission") ||
            message.localizedCaseInsensitiveContains("password") ||
            message.localizedCaseInsensitiveContains("sudo") ||
            message.localizedCaseInsensitiveContains("root")
    }
}
