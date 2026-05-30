import Foundation

struct GuardActivityEvaluator {
    static func isActualGuardActive(snapshot: BatterySnapshot, backendStatus: ChargeBackendStatus) -> Bool {
        guard backendStatus.backendName.localizedCaseInsensitiveContains("batt"),
              backendStatus.isAvailable,
              snapshot.isACConnected,
              snapshot.powerSourceType == .ac,
              backendStatus.battDisabled == false,
              let upperLimit = backendStatus.actualUpperLimitPercent,
              backendStatus.actualLowerLimitPercent != nil else {
            return false
        }

        let currentCharge = backendStatus.currentChargePercent ?? snapshot.batteryPercent
        let state = backendStatus.batteryStateText?.lowercased() ?? ""
        let batteryPowerNearZero = abs(snapshot.batteryPowerWatts ?? backendStatus.chargeRateWatts ?? 999) <= 0.25
        let batteryCurrentNearZero = abs(snapshot.amperageMilliamps ?? 999_999) <= 100

        if let currentCharge, currentCharge >= upperLimit {
            if backendStatus.allowCharging == false {
                return true
            }
            if state.contains("not charging") || state.contains("charged") {
                return true
            }
            if batteryPowerNearZero || batteryCurrentNearZero {
                return true
            }
        }

        return false
    }
}
