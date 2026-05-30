import Foundation

protocol ChargeLimitController {
    func isAvailable() -> Bool
    func getBackendName() -> String
    func getCurrentLimit() -> Int?
    func getWriteAccess() -> ChargeWriteAccess
    func setChargeLimit(percent: Int) throws
    func setLowerLimitDelta(percent: Int) throws
    func enableAdapter() throws
    func disableChargeLimit() throws
    func getStatus() throws -> ChargeBackendStatus
}

extension ChargeLimitController {
    func validateLimit(_ percent: Int) throws {
        guard ChargeLimitPreset.allCases.map(\.rawValue).contains(percent) else {
            throw ChargeLimitError.invalidLimit(percent)
        }
    }

    func validateDelta(_ percent: Int) throws {
        guard [2, 5, 10].contains(percent) else {
            throw ChargeLimitError.invalidDelta(percent)
        }
    }
}
