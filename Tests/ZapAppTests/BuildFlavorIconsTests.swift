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

    private func appBaseIcon() throws -> NSImage {
        try XCTUnwrap(NSImage(contentsOf: packageRootURL.appendingPathComponent("Resources/Zap.icns")))
    }

    func testFlavorIsDevelopmentOnlyForDevBundleIdentifier() {
        XCTAssertEqual(AppBuildFlavor(bundleIdentifier: "com.woosublee.zap.dev"), .development)
        XCTAssertEqual(AppBuildFlavor(bundleIdentifier: "com.woosublee.zap"), .official)
        XCTAssertEqual(AppBuildFlavor(bundleIdentifier: nil), .official)
    }

    func testMenuBarIconsAreEighteenPointTemplates() throws {
        for flavor in [AppBuildFlavor.official, .development] {
            let icon = BuildFlavorIcons.menuBarIcon(flavor: flavor)
            XCTAssertTrue(icon.isTemplate, "\(flavor)")
            XCTAssertEqual(icon.size, NSSize(width: 18, height: 18), "\(flavor)")
        }
    }

    func testDevelopmentMenuBarIconFillsBackgroundAndCutsOutTheMark() throws {
        let official = try alphaMap(BuildFlavorIcons.menuBarIcon(flavor: .official))
        let development = try alphaMap(BuildFlavorIcons.menuBarIcon(flavor: .development))

        // Edge of the canvas (outside the official mark) is filled in the dev icon.
        XCTAssertLessThan(official.alpha(x: 18, y: 2), 0.1)
        XCTAssertGreaterThan(development.alpha(x: 18, y: 2), 0.9)

        // Pixels that the dev icon draws the mark over are cut out of the fill.
        let insetMark = try alphaMap(BuildFlavorIcons.developmentMark())
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

    func testDevelopmentBoltIsCloseToOfficialBoltSize() throws {
        let official = try alphaMap(BuildFlavorIcons.menuBarIcon(flavor: .official)).opaqueBounds()
        let developmentMark = try alphaMap(BuildFlavorIcons.developmentMark()).opaqueBounds()

        XCTAssertGreaterThanOrEqual(official.height, 14 * 2, "official bolt should fill most of the 18pt canvas")
        XCTAssertGreaterThanOrEqual(developmentMark.height, official.height * 0.75)
    }

    func testBoltKeepsTheChunkyMenuBarProportions() throws {
        let official = try alphaMap(BuildFlavorIcons.menuBarIcon(flavor: .official)).opaqueBounds()

        XCTAssertGreaterThanOrEqual(official.width / official.height, 0.7)
    }

    func testVectorBoltIsSharperThanBundledBitmapAtRetinaScale() throws {
        let bitmap = try XCTUnwrap(NSImage(contentsOf: packageRootURL.appendingPathComponent("Resources/ZapMenuBarIcon.png")))

        let vectorBlur = try alphaMap(BuildFlavorIcons.menuBarIcon(flavor: .official)).partialToOpaqueRatio()
        let bitmapBlur = try alphaMap(bitmap).partialToOpaqueRatio()

        XCTAssertLessThan(vectorBlur, bitmapBlur)
    }

    func testOfficialBuildKeepsBundleAppIcon() throws {
        XCTAssertNil(BuildFlavorIcons.appIcon(base: try appBaseIcon(), flavor: .official))
    }

    func testDevelopmentAppIconAddsOrangeBorderOnTheIconEdge() throws {
        let base = try appBaseIcon()
        let icon = try XCTUnwrap(BuildFlavorIcons.appIcon(base: base, flavor: .development))
        let bitmap = try render(icon, pixels: 256)
        let orange = try XCTUnwrap(BuildFlavorIcons.developmentBorderColor.usingColorSpace(.sRGB))

        XCTAssertEqual(icon.size, base.size)
        // Zap.icns fills the whole canvas, so the border hugs the outer edge...
        let edge = try XCTUnwrap(bitmap.colorAt(x: 2, y: 128)?.usingColorSpace(.sRGB))
        XCTAssertEqual(edge.redComponent, orange.redComponent, accuracy: 0.08)
        XCTAssertEqual(edge.greenComponent, orange.greenComponent, accuracy: 0.08)
        XCTAssertEqual(edge.blueComponent, orange.blueComponent, accuracy: 0.08)
        // ...and does not paint a second rounded rectangle inside the artwork.
        let inside = try XCTUnwrap(bitmap.colorAt(x: Int(256 * 102.0 / 1024.0), y: 128)?.usingColorSpace(.sRGB))
        XCTAssertLessThan(inside.redComponent, 0.4)
    }

    func testDevelopmentBorderColorIsFixedSRGBOrange() throws {
        let color = try XCTUnwrap(BuildFlavorIcons.developmentBorderColor.usingColorSpace(.sRGB))
        XCTAssertEqual(color.redComponent, 1, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 0.584, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 0, accuracy: 0.01)
    }

    func testAppIconIsAppliedAfterLaunchFinishes() throws {
        let app = try String(contentsOf: packageRootURL.appendingPathComponent("Sources/ZapApp/ZapApp.swift"))
        let delegate = try String(contentsOf: packageRootURL.appendingPathComponent("Sources/ZapApp/Services/ZapApplicationDelegate.swift"))

        XCTAssertTrue(app.contains("BuildFlavorIcons.menuBarIcon(flavor: AppBuildFlavor.current)"))
        XCTAssertFalse(app.contains("BuildFlavorIcons.appIcon("))
        XCTAssertTrue(delegate.contains("func applicationDidFinishLaunching("))
        XCTAssertTrue(delegate.contains("BuildFlavorIcons.appIcon("))
    }

    // MARK: - Helpers

    private struct AlphaMap {
        let width: Int
        let height: Int
        let bitmap: NSBitmapImageRep

        func alpha(x: Int, y: Int) -> CGFloat {
            bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
        }

        func partialToOpaqueRatio() -> Double {
            var partial = 0
            var opaque = 0
            for y in 0..<height {
                for x in 0..<width {
                    let value = alpha(x: x, y: y)
                    if value > 0.95 { opaque += 1 } else if value > 0.05 { partial += 1 }
                }
            }
            return Double(partial) / Double(max(opaque, 1))
        }

        func opaqueBounds() -> CGRect {
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where alpha(x: x, y: y) > 0.5 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            return maxX < 0 ? .zero : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
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
