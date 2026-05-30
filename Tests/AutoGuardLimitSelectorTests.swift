import XCTest
@testable import MacACGuard

final class AutoGuardLimitSelectorTests: XCTestCase {
    func testAutoLimitClampsToThirtyEightyAndUsesExactPercentInsideRange() {
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 25), 30)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 29), 30)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 30), 30)

        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 57), 57)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 61), 61)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 71), 71)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 76), 76)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 80), 80)

        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 83), 80)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 95), 80)
    }

    func testAutoGuardUsesOnePercentDelta() {
        XCTAssertEqual(AutoGuardLimitSelector.defaultDelta, 1)
    }

    func testAutoGuardRangeDescriptionUsesOnePercentDelta() {
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 25), "29–30%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 30), "29–30%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 57), "56–57%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 71), "70–71%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 76), "75–76%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 83), "79–80%")
    }
}
