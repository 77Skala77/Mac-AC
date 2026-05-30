import XCTest
@testable import MacACGuard

final class AuthorizationTests: XCTestCase {
    func testWriteBackendResolverPrefersHelper() {
        let access = WriteBackendResolver.select(
            helperAvailable: true,
            directWriteSucceeded: true,
            statusAvailable: true
        )

        XCTAssertEqual(access.backend, .privilegedHelper)
        XCTAssertEqual(access.authorizationState, .authorized)
    }

    func testWriteBackendResolverUsesDirectBattAfterSuccessfulWrite() {
        let access = WriteBackendResolver.select(
            helperAvailable: false,
            directWriteSucceeded: true,
            statusAvailable: true
        )

        XCTAssertEqual(access.backend, .directBatt)
        XCTAssertEqual(access.authorizationState, .notRequired)
    }

    func testWriteBackendResolverUsesManualSetupAfterFailedWrite() {
        let access = WriteBackendResolver.select(
            helperAvailable: false,
            directWriteSucceeded: false,
            statusAvailable: true
        )

        XCTAssertEqual(access.backend, .manualSetupRequired)
        XCTAssertEqual(access.authorizationState, .required)
    }

    func testWriteBackendResolverUsesMonitorOnlyWithoutBattStatus() {
        let access = WriteBackendResolver.select(
            helperAvailable: false,
            directWriteSucceeded: false,
            statusAvailable: false
        )

        XCTAssertEqual(access.backend, .monitorOnly)
    }

    func testManualSetupCommandsContainOnlyAllowlistedOperations() throws {
        let generator = ManualSetupCommandGenerator()

        XCTAssertEqual(
            try generator.directCommands(limit: 70, delta: 5),
            [
                "batt limit 70",
                "batt lower-limit-delta 5",
                "batt adapter enable",
                "batt status"
            ]
        )
        XCTAssertEqual(
            try generator.sudoCommands(limit: 70, delta: 5),
            [
                "sudo batt limit 70",
                "sudo batt lower-limit-delta 5",
                "sudo batt adapter enable",
                "batt status"
            ]
        )
    }

    func testManualSetupCommandsRejectUnsupportedValues() {
        let generator = ManualSetupCommandGenerator()

        XCTAssertNoThrow(try generator.directCommands(limit: 35, delta: 1))
        XCTAssertNoThrow(try generator.directCommands(limit: 71, delta: 1))

        XCTAssertThrowsError(try generator.directCommands(limit: 29, delta: 1))
        XCTAssertThrowsError(try generator.directCommands(limit: 81, delta: 1))
        XCTAssertThrowsError(try generator.directCommands(limit: 70, delta: 3))
    }

    func testPrivilegedHelperValidatesAllowlistedValues() throws {
        let client = FakePrivilegedHelperClient()
        let backend = PrivilegedHelperBackend(client: client)

        try backend.setChargeLimit(percent: 70)
        try backend.setChargeLimit(percent: 35)
        try backend.setChargeLimit(percent: 71)
        try backend.setLowerLimitDelta(percent: 1)
        try backend.setLowerLimitDelta(percent: 5)
        try backend.enableAdapter()
        try backend.disableChargeLimit()

        XCTAssertEqual(client.limits, [70, 35, 71])
        XCTAssertEqual(client.deltas, [1, 5])
        XCTAssertEqual(client.enableAdapterCallCount, 1)
        XCTAssertEqual(client.disableCallCount, 1)

        XCTAssertThrowsError(try backend.setChargeLimit(percent: 29))
        XCTAssertThrowsError(try backend.setChargeLimit(percent: 81))
        XCTAssertThrowsError(try backend.setChargeLimit(percent: 100))
        XCTAssertThrowsError(try backend.setLowerLimitDelta(percent: 0))
        XCTAssertThrowsError(try backend.setLowerLimitDelta(percent: 3))
        XCTAssertThrowsError(try backend.setLowerLimitDelta(percent: 11))
    }
}

private final class FakePrivilegedHelperClient: PrivilegedHelperClient {
    var limits: [Int] = []
    var deltas: [Int] = []
    var enableAdapterCallCount = 0
    var disableCallCount = 0

    func healthCheck() -> Bool {
        true
    }

    func getStatus() throws -> ChargeBackendStatus {
        .unknown
    }

    func setChargeLimit(percent: Int) throws {
        limits.append(percent)
    }

    func setLowerLimitDelta(percent: Int) throws {
        deltas.append(percent)
    }

    func enableAdapter() throws {
        enableAdapterCallCount += 1
    }

    func disableLimit() throws {
        disableCallCount += 1
    }
}
