import Foundation

final class MonitorOnlyFallbackBackend: ChargeLimitController {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func isAvailable() -> Bool {
        false
    }

    func getBackendName() -> String {
        "Monitor only"
    }

    func getCurrentLimit() -> Int? {
        nil
    }

    func getWriteAccess() -> ChargeWriteAccess {
        .monitorOnly
    }

    func setChargeLimit(percent: Int) throws {
        throw ChargeLimitError.backendUnavailable(reason)
    }

    func setLowerLimitDelta(percent: Int) throws {
        throw ChargeLimitError.backendUnavailable(reason)
    }

    func enableAdapter() throws {
        throw ChargeLimitError.backendUnavailable(reason)
    }

    func disableChargeLimit() throws {
        throw ChargeLimitError.backendUnavailable(reason)
    }

    func getStatus() throws -> ChargeBackendStatus {
        ChargeBackendStatus(
            backendName: getBackendName(),
            isAvailable: false,
            isMonitorOnly: true,
            currentLimit: nil,
            lowerLimitDelta: nil,
            requiresPrivileges: false,
            details: "На этом Mac доступен только мониторинг. Управление лимитом зарядки недоступно безопасным способом.",
            lastError: reason
        )
    }
}
