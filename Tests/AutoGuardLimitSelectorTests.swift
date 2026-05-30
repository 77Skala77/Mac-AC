import XCTest
@testable import MacACGuard

final class AutoGuardLimitSelectorTests: XCTestCase {
    func testAutoLimitMapping() {
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 30), .extremeReserve)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 40), .lowReserve)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 50), .longevity)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 60), .recommendedNetwork)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 67), .gamingNetwork)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 71), .softProtection)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 83), .softProtection)
    }

    func testAutoGuardUsesFivePercentDelta() {
        XCTAssertEqual(AutoGuardLimitSelector.defaultDelta, 5)
    }
}
