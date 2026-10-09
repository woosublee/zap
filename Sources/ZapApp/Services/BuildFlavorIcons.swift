import AppKit

enum BuildFlavorIcons {
    static let menuBarIconSize = NSSize(width: 18, height: 18)
    static let officialBoltHeight: CGFloat = 16
    static let developmentBoltHeight: CGFloat = 13
    static let developmentCornerRadius: CGFloat = 4

    /// Bolt outline traced from the app icon (Zap.icns), in a 168×328 box with a
    /// bottom-left origin: top tip, right notch, right point, bottom tip, left
    /// notch, left point.
    private static let boltOutline: [CGPoint] = [
        CGPoint(x: 111, y: 328),
        CGPoint(x: 90, y: 208),
        CGPoint(x: 168, y: 208),
        CGPoint(x: 34, y: 0),
        CGPoint(x: 72, y: 160),
        CGPoint(x: 0, y: 160)
    ]
    private static let boltOutlineSize = CGSize(width: 168, height: 328)
    /// The app icon's bolt is too slender at menu bar size, so the menu bar mark
    /// is widened to match the chunkier proportions of the previous bitmap icon.
    private static let menuBarBoltWidthScale: CGFloat = 1.45

    /// Official builds draw the bolt alone. Development builds draw a filled
    /// rounded square with the bolt cut out, so the menu bar shows a white tile in
    /// dark mode and a black tile in light mode. Both are vector-drawn so they stay
    /// sharp on Retina displays.
    static func menuBarIcon(flavor: AppBuildFlavor) -> NSImage {
        let icon: NSImage
        switch flavor {
        case .official:
            icon = NSImage(size: menuBarIconSize, flipped: false) { rect in
                NSColor.black.setFill()
                boltPath(height: officialBoltHeight, centeredIn: rect).fill()
                return true
            }
        case .development:
            icon = NSImage(size: menuBarIconSize, flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(
                    roundedRect: rect,
                    xRadius: developmentCornerRadius,
                    yRadius: developmentCornerRadius
                ).fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                boltPath(height: developmentBoltHeight, centeredIn: rect).fill()
                return true
            }
        }
        icon.isTemplate = true
        return icon
    }

    /// The bolt as the development tile cuts it out, on an 18pt canvas.
    static func developmentMark() -> NSImage {
        NSImage(size: menuBarIconSize, flipped: false) { rect in
            NSColor.black.setFill()
            boltPath(height: developmentBoltHeight, centeredIn: rect).fill()
            return true
        }
    }

    private static func boltPath(height: CGFloat, centeredIn rect: NSRect) -> NSBezierPath {
        let scale = height / boltOutlineSize.height
        let horizontalScale = scale * menuBarBoltWidthScale
        let origin = CGPoint(
            x: rect.midX - boltOutlineSize.width * horizontalScale / 2,
            y: rect.midY - height / 2
        )
        let path = NSBezierPath()
        for (index, point) in boltOutline.enumerated() {
            let scaled = CGPoint(x: origin.x + point.x * horizontalScale, y: origin.y + point.y * scale)
            if index == 0 {
                path.move(to: scaled)
            } else {
                path.line(to: scaled)
            }
        }
        path.close()
        return path
    }

    /// Fixed sRGB orange so the border (and its tests) do not shift with
    /// appearance or Increase Contrast, as `NSColor.systemOrange` does.
    static let developmentBorderColor = NSColor(srgbRed: 1, green: 0.584, blue: 0, alpha: 1)

    /// Development builds get the bundled icon with an orange border along its
    /// outer edge. Zap.icns fills the whole canvas with ~230/1024 rounded corners,
    /// so the border follows that shape. Official builds return nil and keep the
    /// bundle icon.
    static func appIcon(base: NSImage, flavor: AppBuildFlavor) -> NSImage? {
        guard flavor == .development else { return nil }

        return NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)

            let scale = rect.width / 1024
            let lineWidth = 40 * scale
            let tile = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let radius = 230 * scale - lineWidth / 2
            let border = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
            border.lineWidth = lineWidth
            developmentBorderColor.setStroke()
            border.stroke()
            return true
        }
    }
}
