import XCTest
@testable import FocusLock

final class FocusEventTests: XCTestCase {
    func testFocusEventCreation() {
        let event = FocusEvent(
            appName: "SecurityAgent",
            bundleIdentifier: "com.apple.SecurityAgent",
            previousAppName: "Terminal",
            wasBlocked: true
        )

        XCTAssertEqual(event.appName, "SecurityAgent")
        XCTAssertEqual(event.bundleIdentifier, "com.apple.SecurityAgent")
        XCTAssertEqual(event.previousAppName, "Terminal")
        XCTAssertTrue(event.wasBlocked)
        XCTAssertNotNil(event.timestamp)
    }

    func testFocusEventFormattedTime() {
        let event = FocusEvent(
            appName: "Test",
            bundleIdentifier: "com.test",
            previousAppName: nil,
            wasBlocked: false
        )

        // Should return HH:mm:ss format
        XCTAssertTrue(event.formattedTime.contains(":"))
        XCTAssertEqual(event.formattedTime.count, 8) // "HH:mm:ss"
    }
}
