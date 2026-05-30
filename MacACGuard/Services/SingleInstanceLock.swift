import Darwin
import Foundation

enum SingleInstanceLockError: LocalizedError {
    case alreadyRunning(pid: pid_t)
    case cannotCreate(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning(let pid):
            "Another MacACGuard instance is already running with PID \(pid)."
        case .cannotCreate(let message):
            message
        }
    }
}

final class SingleInstanceLock {
    let url: URL
    private let pid: pid_t
    private var released = false

    private init(url: URL, pid: pid_t) {
        self.url = url
        self.pid = pid
    }

    static func acquire(url: URL = AppPaths.instanceLockURL) throws -> SingleInstanceLock {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let existingPID = readPID(from: url) {
            if processIsRunning(existingPID) {
                throw SingleInstanceLockError.alreadyRunning(pid: existingPID)
            }
            try? FileManager.default.removeItem(at: url)
        }

        let pid = getpid()
        do {
            try "\(pid)\n".write(to: url, atomically: true, encoding: .utf8)
            return SingleInstanceLock(url: url, pid: pid)
        } catch {
            throw SingleInstanceLockError.cannotCreate("Cannot create MacACGuard lock file: \(error.localizedDescription)")
        }
    }

    func release() {
        guard !released else { return }
        released = true

        if Self.readPID(from: url) == pid {
            try? FileManager.default.removeItem(at: url)
        }
    }

    deinit {
        release()
    }

    private static func readPID(from url: URL) -> pid_t? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let parsed = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              parsed > 0 else {
            return nil
        }
        return parsed
    }

    private static func processIsRunning(_ pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}
