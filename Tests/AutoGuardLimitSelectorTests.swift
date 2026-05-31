import XCTest
@testable import MacACGuard

final class AutoGuardLimitSelectorTests: XCTestCase {
    func testAutoLimitClampsToFiveHundredAndUsesExactPercentInsideRange() {
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 4), 5)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 5), 5)

        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 17), 17)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 25), 25)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 29), 29)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 30), 30)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 57), 57)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 61), 61)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 71), 71)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 76), 76)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 80), 80)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 83), 83)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 95), 95)
        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 100), 100)

        XCTAssertEqual(AutoGuardLimitSelector.limit(for: 101), 100)
    }

    func testAutoGuardUsesOnePercentDelta() {
        XCTAssertEqual(AutoGuardLimitSelector.defaultDelta, 1)
    }

    func testAutoGuardRangeDescriptionUsesOnePercentDelta() {
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 4), "4–5%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 5), "4–5%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 17), "16–17%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 25), "24–25%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 30), "29–30%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 57), "56–57%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 71), "70–71%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 76), "75–76%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 83), "82–83%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 100), "99–100%")
        XCTAssertEqual(AutoGuardLimitSelector.rangeDescription(for: 101), "99–100%")
    }
}
