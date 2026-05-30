import Foundation

protocol PrivilegedHelperClient {
    func healthCheck() -> Bool
    func getStatus() throws -> ChargeBackendStatus
    func setChargeLimit(percent: Int) throws
    func setLowerLimitDelta(percent: Int) throws
    func enableAdapter() throws
    func disableLimit() throws
}

/// Packaging the real XPC helper requires a signed app bundle, helper target,
/// launchd plist, and designated-requirement checks. SwiftPM keeps this client
/// deliberately unavailable until that product packaging stage is present.
final class PackagedPrivilegedHelperClient: PrivilegedHelperClient {
    static let machServiceName = "com.macacguard.helper"

    func healthCheck() -> Bool {
        false
    }

    func getStatus() throws -> ChargeBackendStatus {
        throw unavailableError
    }

    func setChargeLimit(percent: Int) throws {
        throw unavailableError
    }

    func setLowerLimitDelta(percent: Int) throws {
        throw unavailableError
    }

    func enableAdapter() throws {
        throw unavailableError
    }

    func disableLimit() throws {
        throw unavailableError
    }

    private var unavailableError: ChargeLimitError {
        .helperUnavailable("Signed privileged helper packaging is not installed in this Swift Package build.")
    }
}

final class PrivilegedHelperBackend: ChargeLimitController {
    private let client: PrivilegedHelperClient

    init(client: PrivilegedHelperClient) {
        self.client = client
    }

    func isAvailable() -> Bool {
        client.healthCheck()
    }

    func getBackendName() -> String {
        "Mac AC Guard privileged helper"
    }

    func getCurrentLimit() -> Int? {
        try? client.getStatus().currentLimit
    }

    func getWriteAccess() -> ChargeWriteAccess {
        ChargeWriteAccess(
            backend: .privilegedHelper,
            authorizationState: isAvailable() ? .authorized : .helperNeedsInstall,
            lastWriteError: isAvailable() ? nil : "Signed privileged helper packaging is not installed."
        )
    }

    func setChargeLimit(percent: Int) throws {
        try validateLimit(percent)
        try client.setChargeLimit(percent: percent)
    }

    func setLowerLimitDelta(percent: Int) throws {
        try validateDelta(percent)
        try client.setLowerLimitDelta(percent: percent)
    }

    func enableAdapter() throws {
        try client.enableAdapter()
    }

    func disableChargeLimit() throws {
        try client.disableLimit()
    }

    func getStatus() throws -> ChargeBackendStatus {
        try client.getStatus()
    }
}

struct WriteBackendResolver {
    static func select(
        helperAvailable: Bool,
        directWriteSucceeded: Bool?,
        statusAvailable: Bool
    ) -> ChargeWriteAccess {
        if helperAvailable {
            return ChargeWriteAccess(backend: .privilegedHelper, authorizationState: .authorized, lastWriteError: nil)
        }
        if directWriteSucceeded == true {
            return ChargeWriteAccess(backend: .directBatt, authorizationState: .notRequired, lastWriteError: nil)
        }
        if statusAvailable, directWriteSucceeded == false {
            return ChargeWriteAccess(backend: .manualSetupRequired, authorizationState: .required, lastWriteError: nil)
        }
        if statusAvailable {
            return ChargeWriteAccess(backend: .directBatt, authorizationState: .unknown, lastWriteError: nil)
        }
        return .monitorOnly
    }
}
