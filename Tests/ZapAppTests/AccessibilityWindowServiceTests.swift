import CoreGraphics
import XCTest
@testable import ZapApp
@testable import ZapCore

final class AccessibilityWindowServiceTests: XCTestCase {
    func testFrameConvertsAXTopLeftCoordinatesToAppKitBottomLeftCoordinates() throws {
        let client = MockAXUIElementClient()
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        client.cgPointAttributes["window-1:kAXPositionAttribute"] = CGPoint(x: 100, y: 200)
        client.cgSizeAttributes["window-1:kAXSizeAttribute"] = CGSize(width: 640, height: 480)
        let service = AccessibilityWindowService(client: client, screens: singleMainScreen())

        let frame = try service.frame(of: window)

        XCTAssertEqual(frame, CGRect(x: 100, y: 220, width: 640, height: 480))
    }

    func testFrameThrowsWhenSizeAttributeFails() {
        let client = MockAXUIElementClient()
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        client.cgPointAttributes["window-1:kAXPositionAttribute"] = CGPoint(x: 100, y: 200)
        client.sizeAttributeError = .failure
        let service = AccessibilityWindowService(client: client)

        XCTAssertThrowsError(try service.frame(of: window)) { error in
            XCTAssertEqual(error as? AccessibilityWindowError, .frameReadFailed(attribute: "kAXSizeAttribute"))
        }
    }

    func testSetFrameConvertsAppKitBottomLeftCoordinatesToAXTopLeftCoordinates() throws {
        let client = MockAXUIElementClient()
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let service = AccessibilityWindowService(client: client, screens: singleMainScreen())

        try service.setFrame(CGRect(x: 0, y: 463, width: 1440, height: 437), of: window)

        XCTAssertEqual(client.setOperations.map(\.attribute), ["kAXSizeAttribute", "kAXPositionAttribute", "kAXSizeAttribute"])
        XCTAssertEqual(client.setOperations[0].sizeValue, CGSize(width: 1440, height: 437))
        XCTAssertEqual(client.setOperations[1].pointValue, CGPoint(x: 0, y: 0))
        XCTAssertEqual(client.setOperations[2].sizeValue, CGSize(width: 1440, height: 437))
    }

    func testSetFrameUsesTargetDisplayWhenWritingAuxiliaryDisplayFrame() throws {
        let client = MockAXUIElementClient()
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let service = AccessibilityWindowService(client: client, screens: lowerAuxiliaryScreens())

        try service.setFrame(CGRect(x: 1440, y: -1055, width: 960, height: 1055), of: window)

        XCTAssertEqual(client.setOperations[1].pointValue, CGPoint(x: 1440, y: 900))
    }

    func testCoordinateConversionUsesFirstScreenAsMenuBarReferenceLikeSpectacle() throws {
        let client = MockAXUIElementClient()
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        client.cgPointAttributes["window-1:kAXPositionAttribute"] = CGPoint(x: 1440, y: 900)
        client.cgSizeAttributes["window-1:kAXSizeAttribute"] = CGSize(width: 960, height: 1055)
        let service = AccessibilityWindowService(client: client, screens: firstScreenReferenceWithDifferentMainScreen())

        let frame = try service.frame(of: window)
        try service.setFrame(frame, of: window)

        XCTAssertEqual(frame, CGRect(x: 1440, y: -1055, width: 960, height: 1055))
        XCTAssertEqual(client.setOperations[1].pointValue, CGPoint(x: 1440, y: 900))
    }

    func testSetFrameThrowsWhenAXSetAttributeFails() {
        let client = MockAXUIElementClient()
        client.setAttributeError = .failure
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let service = AccessibilityWindowService(client: client)

        XCTAssertThrowsError(try service.setFrame(CGRect(x: 20, y: 30, width: 800, height: 600), of: window)) { error in
            XCTAssertEqual(error as? AccessibilityWindowError, .frameWriteFailed(attribute: "kAXSizeAttribute"))
        }
    }

    func testFrontmostWindowThrowsWhenFocusedWindowIsMissing() {
        let client = MockAXUIElementClient()
        client.frontmostProcessIdentifier = 42
        client.focusedWindowResult = .failure(.cannotComplete)
        let service = AccessibilityWindowService(client: client)

        XCTAssertThrowsError(try service.frontmostWindow()) { error in
            XCTAssertEqual(error as? AccessibilityWindowError, .focusedWindowMissing)
        }
    }

    func testFrontmostWindowThrowsAPIDisabledWhenTargetAppAccessibilityAPIIsDisabled() {
        let client = MockAXUIElementClient()
        client.frontmostProcessIdentifier = 42
        client.focusedWindowResult = .failure(.apiDisabled)
        let service = AccessibilityWindowService(client: client)

        XCTAssertThrowsError(try service.frontmostWindow()) { error in
            XCTAssertEqual(error as? AccessibilityWindowError, .accessibilityAPIDisabled)
        }
    }

    func testFrontmostWindowMarksSheetAndSystemDialog() throws {
        let client = MockAXUIElementClient()
        client.frontmostProcessIdentifier = 42
        client.frontmostApplicationIdentifier = "com.example.App"
        client.focusedWindowResult = .success(AccessibilityElement.mock(id: "window-1"))
        client.stringAttributes["window-1:kAXRoleAttribute"] = "AXSheet"
        client.stringAttributes["window-1:kAXSubroleAttribute"] = "AXSystemDialog"
        let service = AccessibilityWindowService(client: client)

        let window = try service.frontmostWindow()

        XCTAssertEqual(window.applicationIdentifier, "com.example.App")
        XCTAssertTrue(window.isSheet)
        XCTAssertTrue(window.isSystemDialog)
    }
}

private func singleMainScreen() -> MockAccessibilityScreenProvider {
    MockAccessibilityScreenProvider(displayFrames: [
        DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875),
            isMain: true
        )
    ])
}

private func lowerAuxiliaryScreens() -> MockAccessibilityScreenProvider {
    MockAccessibilityScreenProvider(displayFrames: [
        DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875),
            isMain: true
        ),
        DisplayFrame(
            frame: CGRect(x: 1440, y: -1080, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: -1055, width: 1920, height: 1055),
            isMain: false
        )
    ])
}

private func firstScreenReferenceWithDifferentMainScreen() -> MockAccessibilityScreenProvider {
    MockAccessibilityScreenProvider(displayFrames: [
        DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875),
            isMain: false
        ),
        DisplayFrame(
            frame: CGRect(x: 1440, y: -1080, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: -1055, width: 1920, height: 1055),
            isMain: true
        )
    ])
}

private struct MockAccessibilityScreenProvider: ScreenProviding {
    let displayFrames: [DisplayFrame]
}

private final class MockAXUIElementClient: AXUIElementClienting {
    var frontmostProcessIdentifier: pid_t?
    var frontmostApplicationIdentifier: String?
    var focusedWindowResult: Result<AccessibilityElement, AXUIElementClientError> = .failure(.cannotComplete)
    var stringAttributes: [String: String] = [:]
    var cgPointAttributes: [String: CGPoint] = [:]
    var cgSizeAttributes: [String: CGSize] = [:]
    var sizeAttributeError: AXUIElementClientError?
    var setAttributeError: AXUIElementClientError?
    var setOperations: [SetOperation] = []

    func applicationElement(processIdentifier: pid_t) -> AccessibilityElement {
        AccessibilityElement.mock(id: "app-\(processIdentifier)")
    }

    func copyElementAttribute(_ attribute: String, of element: AccessibilityElement) throws -> AccessibilityElement {
        if attribute == "kAXFocusedWindowAttribute" {
            return try focusedWindowResult.get()
        }
        throw AXUIElementClientError.failure
    }

    func copyStringAttribute(_ attribute: String, of element: AccessibilityElement) throws -> String {
        guard let value = stringAttributes["\(element.id):\(attribute)"] else {
            throw AXUIElementClientError.failure
        }
        return value
    }

    func copyCGPointAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CGPoint {
        guard let value = cgPointAttributes["\(element.id):\(attribute)"] else {
            throw AXUIElementClientError.failure
        }
        return value
    }

    func copyCGSizeAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CGSize {
        if let sizeAttributeError {
            throw sizeAttributeError
        }
        guard let value = cgSizeAttributes["\(element.id):\(attribute)"] else {
            throw AXUIElementClientError.failure
        }
        return value
    }

    func setCGSizeAttribute(_ attribute: String, of element: AccessibilityElement, value: CGSize) throws {
        if let setAttributeError {
            throw setAttributeError
        }
        setOperations.append(SetOperation(attribute: attribute, sizeValue: value, pointValue: nil))
    }

    func setCGPointAttribute(_ attribute: String, of element: AccessibilityElement, value: CGPoint) throws {
        if let setAttributeError {
            throw setAttributeError
        }
        setOperations.append(SetOperation(attribute: attribute, sizeValue: nil, pointValue: value))
    }
}

private struct SetOperation: Equatable {
    let attribute: String
    let sizeValue: CGSize?
    let pointValue: CGPoint?
}
