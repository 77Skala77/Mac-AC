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
    /// Auto Guard can use exact current battery percent, not only manual presets.
    /// Safe automatic range: 5...100.
    func validateLimit(_ percent: Int) throws {
        guard (5...100).contains(percent) else {
            throw ChargeLimitError.invalidLimit(percent)
        }
    }

    /// Auto Guard uses delta 1.
    /// Manual mode may still use larger deltas.
    func validateDelta(_ percent: Int) throws {
        guard [1, 2, 5, 10].contains(percent) else {
            throw ChargeLimitError.invalidDelta(percent)
        }
    }
}
