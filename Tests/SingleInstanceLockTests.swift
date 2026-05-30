import XCTest
@testable import MacACGuard

final class SingleInstanceLockTests: XCTestCase {
    func testReleasedLockCanBeAcquiredAgain() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("MacACGuard.lock")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try SingleInstanceLock.acquire(url: url)
        first.release()
        let second = try SingleInstanceLock.acquire(url: url)
        second.release()

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
