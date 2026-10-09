import AppKit

enum BuildFlavorIcons {
    static let menuBarIconSize = NSSize(width: 18, height: 18)
    static let developmentMarkInset: CGFloat = 3
    static let developmentCornerRadius: CGFloat = 4

    /// Official builds use the bundled mark as-is. Development builds draw a filled
    /// rounded square with the mark cut out, so the menu bar shows a white tile in
    /// dark mode and a black tile in light mode.
    static func menuBarIcon(base: NSImage, flavor: AppBuildFlavor) -> NSImage {
        let icon: NSImage
        switch flavor {
        case .official:
            icon = (base.copy() as? NSImage) ?? base
            icon.size = menuBarIconSize
        case .development:
            let mark = developmentMark(base: base)
            icon = NSImage(size: menuBarIconSize, flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(
                    roundedRect: rect,
                    xRadius: developmentCornerRadius,
                    yRadius: developmentCornerRadius
                ).fill()
                mark.draw(in: rect, from: .zero, operation: .destinationOut, fraction: 1)
                return true
            }
        }
        icon.isTemplate = true
        return icon
    }

    /// The mark scaled into the development tile's inset, on an 18pt canvas.
    static func developmentMark(base: NSImage) -> NSImage {
        NSImage(size: menuBarIconSize, flipped: false) { rect in
            base.draw(
                in: rect.insetBy(dx: developmentMarkInset, dy: developmentMarkInset),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
    }

    /// Development builds get the bundled icon with an orange border on Apple's
    /// 824/1024 icon grid. Official builds return nil and keep the bundle icon.
    static func appIcon(base: NSImage, flavor: AppBuildFlavor) -> NSImage? {
        guard flavor == .development else { return nil }

        return NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)

            let scale = rect.width / 1024
            let lineWidth = 36 * scale
            let tile = rect.insetBy(dx: 100 * scale, dy: 100 * scale)
                .insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let radius = 185 * scale - lineWidth / 2
            let border = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
            border.lineWidth = lineWidth
            NSColor.systemOrange.setStroke()
            border.stroke()
            return true
        }
    }
}
