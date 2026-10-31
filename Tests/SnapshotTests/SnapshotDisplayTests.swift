import XCTest

/// The display logic the popover and widget share. Lives in this bundle
/// because SharedViews is not part of the Swift package.
@MainActor
final class SnapshotDisplayTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    private func snapshot(sessionResetsIn seconds: TimeInterval, stale: Bool = false) -> Snapshot {
        Snapshot(usage: UsageData(
                    fiveHour: UsageNode(utilization: 64,
                                        resetsAt: now.addingTimeInterval(seconds)),
                    sevenDay: nil),
                 stale: stale)
    }

    func testALimitWhoseWindowHasResetHasNoNumber() {
        let elapsed = snapshot(sessionResetsIn: -60)
        XCTAssertNil(elapsed.pct(.session, now: now))
        XCTAssertEqual(elapsed.level(.session, now: now), .none)
        XCTAssertEqual(elapsed.resetsText(.session, now: now), "just reset")
        XCTAssertEqual(elapsed.spokenValue(.session, now: now), "no number, just reset")
    }

    func testALiveLimitSpeaksItsNumberLevelAndReset() {
        let live = snapshot(sessionResetsIn: 2 * 3600 + 14 * 60, stale: true)
        XCTAssertEqual(live.pct(.session, now: now), 64)
        XCTAssertEqual(live.resetsText(.session, now: now), "resets 2h 14m")
        XCTAssertEqual(live.spokenValue(.session, now: now),
                       "64 percent, warn level, resets in 2 hours, 14 minutes, outdated")
    }

    func testAStatusWithoutNumbersNeverClaimsAnUpdate() {
        let never = Snapshot(updatedAt: now, usage: nil, error: "no-token")
        XCTAssertFalse(never.hasNumbers)
        XCTAssertEqual(MenuView.status(never, now: now), "Not updated yet")
        XCTAssertEqual(MenuView.status(snapshot(sessionResetsIn: 60), now: Date()),
                       "Updated just now")
    }

    func testErrorsNameTheNextStepWithoutCodes() {
        XCTAssertEqual(Snapshot(error: "http-401").errorMessage,
                       "Token rejected — open Claude Code in this profile")
        XCTAssertEqual(Snapshot(error: "http-503").errorMessage, "Couldn't update — will retry")
    }
}
