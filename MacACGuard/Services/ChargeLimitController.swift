import Foundation

protocol ChargeLimitController {
    func isAvailable() -> Bool
    func getBackendName() -> String
    func getCurrentLimit() -> Int?
    func setChargeLimit(percent: Int) throws
    func setLowerLimitDelta(percent: Int) throws
    func disableChargeLimit() throws
    func getStatus() throws -> ChargeBackendStatus
}

extension ChargeLimitController {
    func validateLimit(_ percent: Int) throws {
        guard ChargeLimitPreset.allCases.map(\.rawValue).contains(percent) || percent == 100 else {
            throw ChargeLimitError.invalidLimit(percent)
        }
    }
}
