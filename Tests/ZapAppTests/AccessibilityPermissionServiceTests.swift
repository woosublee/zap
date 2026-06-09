import XCTest
@testable import ZapApp

final class AccessibilityPermissionServiceTests: XCTestCase {
    func testIsTrustedDelegatesToAXPermissionClient() {
        let client = MockAXPermissionClient(isTrusted: true)
        let service = AccessibilityPermissionService(client: client)

        XCTAssertTrue(service.isTrusted)
    }

    func testRequestPromptAsksAXClientToShowPrompt() {
        let client = MockAXPermissionClient(isTrusted: false)
        let service = AccessibilityPermissionService(client: client)

        service.requestPrompt()

        XCTAssertEqual(client.requestedPromptValues, [true])
    }
}

private final class MockAXPermissionClient: AXPermissionClienting {
    var trusted: Bool
    var requestedPromptValues: [Bool] = []

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    var isTrusted: Bool {
        trusted
    }

    func requestPrompt(showPrompt: Bool) {
        requestedPromptValues.append(showPrompt)
    }
}
