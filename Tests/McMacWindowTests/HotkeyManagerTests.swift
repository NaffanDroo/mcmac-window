import XCTest
@testable import McMacWindowCore

class HotkeyManagerTests: XCTestCase {

    func testShortcutDescriptionsContainsAllActions() {
        let descriptions = HotkeyManager.shared.shortcutDescriptions()
        // Every WindowAction should appear in the descriptions.
        let allActions: [WindowAction] = [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf,
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .firstThird, .centerThird, .lastThird,
            .leftTwoThirds, .rightTwoThirds,
            .maximize, .center
        ]
        for action in allActions {
            XCTAssertTrue(descriptions.contains { $0.contains(action.rawValue) },
                          "\(action.rawValue) should appear in shortcut descriptions")
        }
    }

    func testShortcutDescriptionsHasGroupHeaders() {
        let descriptions = HotkeyManager.shared.shortcutDescriptions()
        XCTAssertTrue(descriptions.contains("── Halves ──"), "Halves header")
        XCTAssertTrue(descriptions.contains("── Quarters ──"), "Quarters header")
        XCTAssertTrue(descriptions.contains("── Thirds ──"), "Thirds header")
        XCTAssertTrue(descriptions.contains("── Special ──"), "Special header")
    }

    func testShortcutDescriptionsGroupsSeparatedByBlankLines() {
        let descriptions = HotkeyManager.shared.shortcutDescriptions()
        // Groups after the first should be preceded by a blank line separator.
        let blankCount = descriptions.filter { $0.isEmpty }.count
        // 3 blank lines: between Halves→Quarters, Quarters→Thirds, Thirds→Special
        XCTAssertEqual(blankCount, 3, "three blank-line separators between four groups")
    }
}
