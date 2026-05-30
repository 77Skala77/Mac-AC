import Foundation

enum AuthorizationState: Equatable {
    case unknown
    case notRequired
    case required
    case authorized
    case denied
    case helperMissing
    case helperNeedsInstall
    case helperOutdated
    case failed(String)

}

enum WriteBackend: String, Equatable {
    case directBatt
    case privilegedHelper
    case manualSetupRequired
    case monitorOnly

}

struct ChargeWriteAccess: Equatable {
    var backend: WriteBackend
    var authorizationState: AuthorizationState
    var lastWriteError: String?

    static let monitorOnly = ChargeWriteAccess(
        backend: .monitorOnly,
        authorizationState: .helperMissing,
        lastWriteError: nil
    )
}
