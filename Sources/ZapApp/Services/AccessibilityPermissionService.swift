import ApplicationServices

protocol AccessibilityPermissionChecking {
    var isTrusted: Bool { get }
    func requestPrompt()
}

protocol AXPermissionClienting {
    var isTrusted: Bool { get }
    func requestPrompt(showPrompt: Bool)
}

struct AccessibilityPermissionService: AccessibilityPermissionChecking {
    private let client: AXPermissionClienting

    init(client: AXPermissionClienting = AXPermissionClient()) {
        self.client = client
    }

    var isTrusted: Bool {
        client.isTrusted
    }

    func requestPrompt() {
        client.requestPrompt(showPrompt: true)
    }
}

struct AXPermissionClient: AXPermissionClienting {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestPrompt(showPrompt: Bool) {
        let optionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [optionKey: showPrompt] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
