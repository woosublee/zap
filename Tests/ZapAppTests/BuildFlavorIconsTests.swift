import AppKit
import XCTest
@testable import ZapApp

final class BuildFlavorIconsTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func menuBarBaseIcon() throws -> NSImage {
        try XCTUnwrap(NSImage(contentsOf: packageRootURL.appendingPathComponent("Resources/ZapMenuBarIcon.png")))
    }

    private func appBaseIcon() throws -> NSImage {
        try XCTUnwrap(NSImage(contentsOf: packageRootURL.appendingPathComponent("Resources/Zap.icns")))
    }

    func testFlavorIsDevelopmentOnlyForDevBundleIdentifier() {
        XCTAssertEqual(AppBuildFlavor(bundleIdentifier: "com.woosublee.zap.dev"), .development)
        XCTAssertEqual(AppBuildFlavor(bundleIdentifier: "com.woosublee.zap"), .official)
        XCTAssertEqual(AppBuildFlavor(bundleIdentifier: nil), .official)
    }

    func testMenuBarIconsAreEighteenPointTemplates() throws {
        let base = try menuBarBaseIcon()

        for flavor in [AppBuildFlavor.official, .development] {
            let icon = BuildFlavorIcons.menuBarIcon(base: base, flavor: flavor)
            XCTAssertTrue(icon.isTemplate, "\(flavor)")
            XCTAssertEqual(icon.size, NSSize(width: 18, height: 18), "\(flavor)")
        }
    }

    func testDevelopmentMenuBarIconFillsBackgroundAndCutsOutTheMark() throws {
        let base = try menuBarBaseIcon()
        let official = try alphaMap(BuildFlavorIcons.menuBarIcon(base: base, flavor: .official))
        let development = try alphaMap(BuildFlavorIcons.menuBarIcon(base: base, flavor: .development))

        // Edge of the canvas (outside the official mark) is filled in the dev icon.
        XCTAssertLessThan(official.alpha(x: 18, y: 2), 0.1)
        XCTAssertGreaterThan(development.alpha(x: 18, y: 2), 0.9)

        // Pixels that the dev icon draws the mark over are cut out of the fill.
        let insetMark = try alphaMap(BuildFlavorIcons.developmentMark(base: base))
        var markPixels = 0
        var cutOutPixels = 0
        for y in 0..<insetMark.height {
            for x in 0..<insetMark.width where insetMark.alpha(x: x, y: y) > 0.9 {
                markPixels += 1
                if development.alpha(x: x, y: y) < 0.1 { cutOutPixels += 1 }
            }
        }
        XCTAssertGreaterThan(markPixels, 50)
        XCTAssertGreaterThan(Double(cutOutPixels) / Double(markPixels), 0.9)
    }

    func testOfficialBuildKeepsBundleAppIcon() throws {
        XCTAssertNil(BuildFlavorIcons.appIcon(base: try appBaseIcon(), flavor: .official))
    }

    func testDevelopmentAppIconAddsOrangeBorder() throws {
        let base = try appBaseIcon()
        let icon = try XCTUnwrap(BuildFlavorIcons.appIcon(base: base, flavor: .development))
        let bitmap = try render(icon, pixels: 256)

        XCTAssertEqual(icon.size, base.size)
        // Middle of the left edge of Apple's 824/1024 icon grid, on the border stroke.
        let color = try XCTUnwrap(bitmap.colorAt(x: Int(256 * 102.0 / 1024.0), y: 128)?.usingColorSpace(.sRGB))
        XCTAssertGreaterThan(color.redComponent, 0.85)
        XCTAssertGreaterThan(color.greenComponent, 0.35)
        XCTAssertLessThan(color.greenComponent, 0.75)
        XCTAssertLessThan(color.blueComponent, 0.3)
    }

    func testZapAppUsesFlavorIcons() throws {
        let source = try String(contentsOf: packageRootURL.appendingPathComponent("Sources/ZapApp/ZapApp.swift"))

        XCTAssertTrue(source.contains("BuildFlavorIcons.menuBarIcon(base: base, flavor: AppBuildFlavor.current)"))
        XCTAssertTrue(source.contains("if let icon = BuildFlavorIcons.appIcon(base: NSApplication.shared.applicationIconImage, flavor: AppBuildFlavor.current) {\n            NSApplication.shared.applicationIconImage = icon\n        }"))
    }

    // MARK: - Helpers

    private struct AlphaMap {
        let width: Int
        let height: Int
        let bitmap: NSBitmapImageRep

        func alpha(x: Int, y: Int) -> CGFloat {
            bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
        }
    }

    private func alphaMap(_ image: NSImage) throws -> AlphaMap {
        let bitmap = try render(image, pixels: 36)
        return AlphaMap(width: bitmap.pixelsWide, height: bitmap.pixelsHigh, bitmap: bitmap)
    }

    private func render(_ image: NSImage, pixels: Int) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}
