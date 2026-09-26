import ApplicationServices

protocol AccessibilityPermissionChecking {
    var isTrusted: Bool { get }
}

protocol AXPermissionClienting {
    var isTrusted: Bool { get }
}

struct AccessibilityPermissionService: AccessibilityPermissionChecking {
    private let client: AXPermissionClienting

    init(client: AXPermissionClienting = AXPermissionClient()) {
        self.client = client
    }

    var isTrusted: Bool {
        client.isTrusted
    }
}

struct AXPermissionClient: AXPermissionClienting {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }
}
