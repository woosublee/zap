import XCTest
@testable import ZapApp

final class AccessibilityPermissionServiceTests: XCTestCase {
    func testIsTrustedDelegatesToAXPermissionClient() {
        let client = MockAXPermissionClient(isTrusted: true)
        let service = AccessibilityPermissionService(client: client)

        XCTAssertTrue(service.isTrusted)
    }
}

private final class MockAXPermissionClient: AXPermissionClienting {
    var trusted: Bool

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    var isTrusted: Bool {
        trusted
    }
}
