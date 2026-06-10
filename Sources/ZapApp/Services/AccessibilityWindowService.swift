import AppKit
import ApplicationServices
import CoreGraphics
import ZapCore

struct AccessibilityElement {
    let id: String
    fileprivate let rawValue: AXUIElement?

    static func mock(id: String) -> AccessibilityElement {
        AccessibilityElement(id: id, rawValue: nil)
    }

    fileprivate static func real(_ element: AXUIElement) -> AccessibilityElement {
        AccessibilityElement(id: String(describing: element), rawValue: element)
    }
}

struct AccessibilityWindow {
    let applicationIdentifier: String
    let element: AccessibilityElement
    let isSheet: Bool
    let isSystemDialog: Bool

    static func mock(
        applicationIdentifier: String,
        elementID: String,
        isSheet: Bool = false,
        isSystemDialog: Bool = false
    ) -> AccessibilityWindow {
        AccessibilityWindow(
            applicationIdentifier: applicationIdentifier,
            element: .mock(id: elementID),
            isSheet: isSheet,
            isSystemDialog: isSystemDialog
        )
    }
}

enum AccessibilityWindowError: Error, Equatable {
    case accessibilityAPIDisabled
    case frontmostApplicationMissing
    case focusedWindowMissing
    case frameReadFailed(attribute: String)
    case frameWriteFailed(attribute: String)
}

enum AXUIElementClientError: Error, Equatable {
    case apiDisabled
    case cannotComplete
    case failure
    case invalidValue

    init(_ error: AXError) {
        switch error {
        case .apiDisabled:
            self = .apiDisabled
        case .cannotComplete:
            self = .cannotComplete
        case .success:
            self = .failure
        default:
            self = .failure
        }
    }
}

protocol AccessibilityWindowControlling {
    func frontmostWindow() throws -> AccessibilityWindow
    func frame(of window: AccessibilityWindow) throws -> CGRect
    func setFrame(_ frame: CGRect, of window: AccessibilityWindow) throws
}

protocol AXUIElementClienting {
    var frontmostProcessIdentifier: pid_t? { get }
    var frontmostApplicationIdentifier: String? { get }

    func applicationElement(processIdentifier: pid_t) -> AccessibilityElement
    func copyElementAttribute(_ attribute: String, of element: AccessibilityElement) throws -> AccessibilityElement
    func copyStringAttribute(_ attribute: String, of element: AccessibilityElement) throws -> String
    func copyCGPointAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CGPoint
    func copyCGSizeAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CGSize
    func setCGSizeAttribute(_ attribute: String, of element: AccessibilityElement, value: CGSize) throws
    func setCGPointAttribute(_ attribute: String, of element: AccessibilityElement, value: CGPoint) throws
}

struct AccessibilityWindowService: AccessibilityWindowControlling {
    private let client: AXUIElementClienting
    private let screens: ScreenProviding

    init(
        client: AXUIElementClienting = AXUIElementClient(),
        screens: ScreenProviding = NSScreenProvider()
    ) {
        self.client = client
        self.screens = screens
    }

    func frontmostWindow() throws -> AccessibilityWindow {
        guard let processIdentifier = client.frontmostProcessIdentifier else {
            throw AccessibilityWindowError.frontmostApplicationMissing
        }

        let appElement = client.applicationElement(processIdentifier: processIdentifier)
        let windowElement: AccessibilityElement
        do {
            windowElement = try client.copyElementAttribute(AXAttribute.focusedWindow, of: appElement)
        } catch AXUIElementClientError.apiDisabled {
            throw AccessibilityWindowError.accessibilityAPIDisabled
        } catch {
            throw AccessibilityWindowError.focusedWindowMissing
        }

        let role = try? client.copyStringAttribute(AXAttribute.role, of: windowElement)
        let subrole = try? client.copyStringAttribute(AXAttribute.subrole, of: windowElement)

        return AccessibilityWindow(
            applicationIdentifier: client.frontmostApplicationIdentifier ?? String(processIdentifier),
            element: windowElement,
            isSheet: role == AXRole.sheet,
            isSystemDialog: subrole == AXSubrole.systemDialog
        )
    }

    func frame(of window: AccessibilityWindow) throws -> CGRect {
        let position: CGPoint
        let size: CGSize

        do {
            position = try client.copyCGPointAttribute(AXAttribute.position, of: window.element)
        } catch {
            throw AccessibilityWindowError.frameReadFailed(attribute: AXAttribute.position)
        }

        do {
            size = try client.copyCGSizeAttribute(AXAttribute.size, of: window.element)
        } catch {
            throw AccessibilityWindowError.frameReadFailed(attribute: AXAttribute.size)
        }

        let axFrame = CGRect(origin: position, size: size)
        return appKitFrame(fromAXFrame: axFrame)
    }

    func setFrame(_ frame: CGRect, of window: AccessibilityWindow) throws {
        let axFrame = axFrame(fromAppKitFrame: frame)
        try writeSize(axFrame.size, to: window.element)
        try writePosition(axFrame.origin, to: window.element)
        try writeSize(axFrame.size, to: window.element)
    }

    private func appKitFrame(fromAXFrame frame: CGRect) -> CGRect {
        guard let screenReferenceTopY else { return frame }
        return CGRect(
            x: frame.minX,
            y: screenReferenceTopY - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    private func axFrame(fromAppKitFrame frame: CGRect) -> CGRect {
        guard let screenReferenceTopY else { return frame }
        return CGRect(
            x: frame.minX,
            y: screenReferenceTopY - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    private var screenReferenceTopY: CGFloat? {
        screens.displayFrames.first?.frame.maxY
    }

    private func screenContainingTopLeft(of frame: CGRect) -> DisplayFrame? {
        screen(containing: frame.origin)
    }

    private func screenContainingBottomLeft(of frame: CGRect) -> DisplayFrame? {
        screen(containing: CGPoint(x: frame.minX, y: frame.minY))
    }

    private func screen(containing point: CGPoint) -> DisplayFrame? {
        screens.displayFrames.first { display in
            display.frame.contains(point) || display.visibleFrame.contains(point)
        } ?? screens.displayFrames.first(where: \.isMain) ?? screens.displayFrames.first
    }

    private func writeSize(_ size: CGSize, to element: AccessibilityElement) throws {
        do {
            try client.setCGSizeAttribute(AXAttribute.size, of: element, value: size)
        } catch {
            throw AccessibilityWindowError.frameWriteFailed(attribute: AXAttribute.size)
        }
    }

    private func writePosition(_ point: CGPoint, to element: AccessibilityElement) throws {
        do {
            try client.setCGPointAttribute(AXAttribute.position, of: element, value: point)
        } catch {
            throw AccessibilityWindowError.frameWriteFailed(attribute: AXAttribute.position)
        }
    }
}

struct AXUIElementClient: AXUIElementClienting {
    var frontmostProcessIdentifier: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    var frontmostApplicationIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func applicationElement(processIdentifier: pid_t) -> AccessibilityElement {
        AccessibilityElement.real(AXUIElementCreateApplication(processIdentifier))
    }

    func copyElementAttribute(_ attribute: String, of element: AccessibilityElement) throws -> AccessibilityElement {
        let value = try copyAttribute(attribute, of: element)
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw AXUIElementClientError.invalidValue
        }
        return .real(value as! AXUIElement)
    }

    func copyStringAttribute(_ attribute: String, of element: AccessibilityElement) throws -> String {
        guard let value = try copyAttribute(attribute, of: element) as? String else {
            throw AXUIElementClientError.invalidValue
        }
        return value
    }

    func copyCGPointAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CGPoint {
        let value = try copyAttribute(attribute, of: element)
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AXUIElementClientError.invalidValue
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else {
            throw AXUIElementClientError.invalidValue
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            throw AXUIElementClientError.invalidValue
        }
        return point
    }

    func copyCGSizeAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CGSize {
        let value = try copyAttribute(attribute, of: element)
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AXUIElementClientError.invalidValue
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else {
            throw AXUIElementClientError.invalidValue
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            throw AXUIElementClientError.invalidValue
        }
        return size
    }

    func setCGSizeAttribute(_ attribute: String, of element: AccessibilityElement, value: CGSize) throws {
        var mutableValue = value
        guard let axValue = AXValueCreate(.cgSize, &mutableValue) else {
            throw AXUIElementClientError.invalidValue
        }
        try setAttribute(attribute, of: element, value: axValue)
    }

    func setCGPointAttribute(_ attribute: String, of element: AccessibilityElement, value: CGPoint) throws {
        var mutableValue = value
        guard let axValue = AXValueCreate(.cgPoint, &mutableValue) else {
            throw AXUIElementClientError.invalidValue
        }
        try setAttribute(attribute, of: element, value: axValue)
    }

    private func copyAttribute(_ attribute: String, of element: AccessibilityElement) throws -> CFTypeRef {
        guard let rawElement = element.rawValue else {
            throw AXUIElementClientError.invalidValue
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(rawElement, cfAttribute(named: attribute), &value)
        guard error == .success, let value else {
            throw AXUIElementClientError(error)
        }
        return value
    }

    private func setAttribute(_ attribute: String, of element: AccessibilityElement, value: CFTypeRef) throws {
        guard let rawElement = element.rawValue else {
            throw AXUIElementClientError.invalidValue
        }

        let error = AXUIElementSetAttributeValue(rawElement, cfAttribute(named: attribute), value)
        guard error == .success else {
            throw AXUIElementClientError(error)
        }
    }

    private func cfAttribute(named attribute: String) -> CFString {
        switch attribute {
        case AXAttribute.focusedWindow:
            kAXFocusedWindowAttribute as CFString
        case AXAttribute.role:
            kAXRoleAttribute as CFString
        case AXAttribute.subrole:
            kAXSubroleAttribute as CFString
        case AXAttribute.position:
            kAXPositionAttribute as CFString
        case AXAttribute.size:
            kAXSizeAttribute as CFString
        default:
            attribute as CFString
        }
    }
}

enum AXAttribute {
    static let focusedWindow = "kAXFocusedWindowAttribute"
    static let role = "kAXRoleAttribute"
    static let subrole = "kAXSubroleAttribute"
    static let position = "kAXPositionAttribute"
    static let size = "kAXSizeAttribute"
}

private enum AXRole {
    static let sheet = "AXSheet"
}

private enum AXSubrole {
    static let systemDialog = "AXSystemDialog"
}
