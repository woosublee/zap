import ImageIO
import XCTest

final class MenuBarIconResourceTests: XCTestCase {
    func testMenuBarIconUsesMenuBarSizedCanvas() throws {
        let image = try menuBarIconImage()

        XCTAssertLessThanOrEqual(image.width, 20)
        XCTAssertLessThanOrEqual(image.height, 20)
    }

    func testMenuBarIconFillsCanvasLikeAStatusIcon() throws {
        let image = try menuBarIconImage()
        let alphaBounds = try alphaBounds(in: image)

        XCTAssertGreaterThanOrEqual(alphaBounds.width, 12)
        XCTAssertGreaterThanOrEqual(alphaBounds.height, 15)
    }

    private func menuBarIconImage() throws -> CGImage {
        let testSourceURL = URL(fileURLWithPath: #filePath)
        let packageRootURL = testSourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconURL = packageRootURL.appendingPathComponent("Resources/ZapMenuBarIcon.png")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(iconURL as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func alphaBounds(in image: CGImage) throws -> CGRect {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                if pixels[(y * width + x) * 4 + 3] > 0 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
