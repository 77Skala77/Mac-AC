import Foundation

final class IntelSMCBackend: ChargeLimitController {
    func isAvailable() -> Bool {
        false
    }

    func getBackendName() -> String {
        "Intel SMC/BCLM (safe skeleton)"
    }

    func getCurrentLimit() -> Int? {
        nil
    }

    func getWriteAccess() -> ChargeWriteAccess {
        .monitorOnly
    }

    func setChargeLimit(percent: Int) throws {
        throw ChargeLimitError.unsupported("Intel SMC/BCLM control is not enabled in this MVP. If safe control is unavailable, Mac AC Guard stays in monitoring mode.")
    }

    func setLowerLimitDelta(percent: Int) throws {
        throw ChargeLimitError.unsupported("Intel lower-limit delta control is not enabled in this MVP.")
    }

    func enableAdapter() throws {
        throw ChargeLimitError.unsupported("Intel adapter control is not enabled in this MVP.")
    }

    func disableChargeLimit() throws {
        throw ChargeLimitError.unsupported("Intel charge-limit disable is not enabled in this MVP.")
    }

    func getStatus() throws -> ChargeBackendStatus {
        ChargeBackendStatus(
            backendName: getBackendName(),
            isAvailable: false,
            isMonitorOnly: true,
            currentLimit: nil,
            lowerLimitDelta: nil,
            requiresPrivileges: true,
            details: "Intel backend is intentionally a skeleton. macOS 15+ and some SMC/BCLM tools may require unsupported SIP changes; Mac AC Guard will not automate that.",
            lastError: nil
        )
    }
}
