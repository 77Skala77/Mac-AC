import Foundation

struct ShellCommandResult: Equatable {
    var stdout: String
    var stderr: String
    var exitCode: Int32

    var succeeded: Bool {
        exitCode == 0
    }
}

final class ShellCommandRunner {
    func run(
        executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 10
    ) throws -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }

        let waitResult = group.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            process.terminate()
            throw ChargeLimitError.commandFailed("Command timed out: \(executable) \(arguments.joined(separator: " "))")
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ShellCommandResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}
