import CoreGraphics

public struct WindowPositionCalculator: Sendable {
    public init() {}

    public func calculate(_ input: WindowCalculationInput) -> WindowCalculationResult {
        let frame: CGRect

        switch input.action {
        case .fullscreen:
            frame = input.destinationVisibleFrame
        case .center:
            frame = centered(input.windowFrame, in: input.destinationVisibleFrame)
        case .leftHalf:
            frame = leftWeightedRect(
                in: input.destinationVisibleFrame,
                currentWindow: input.windowFrame,
                height: input.destinationVisibleFrame.height,
                y: input.destinationVisibleFrame.minY
            )
        case .rightHalf:
            frame = rightWeightedRect(
                in: input.destinationVisibleFrame,
                currentWindow: input.windowFrame,
                height: input.destinationVisibleFrame.height,
                y: input.destinationVisibleFrame.minY
            )
        case .topHalf:
            frame = verticalWeightedRect(in: input.destinationVisibleFrame, currentWindow: input.windowFrame, edge: .top)
        case .bottomHalf:
            frame = verticalWeightedRect(in: input.destinationVisibleFrame, currentWindow: input.windowFrame, edge: .bottom)
        case .upperLeft:
            frame = leftWeightedRect(
                in: input.destinationVisibleFrame,
                currentWindow: input.windowFrame,
                height: halfHeight(input.destinationVisibleFrame),
                y: upperY(input.destinationVisibleFrame)
            )
        case .upperRight:
            frame = rightWeightedRect(
                in: input.destinationVisibleFrame,
                currentWindow: input.windowFrame,
                height: halfHeight(input.destinationVisibleFrame),
                y: upperY(input.destinationVisibleFrame)
            )
        case .lowerLeft:
            frame = leftWeightedRect(
                in: input.destinationVisibleFrame,
                currentWindow: input.windowFrame,
                height: halfHeight(input.destinationVisibleFrame),
                y: input.destinationVisibleFrame.minY
            )
        case .lowerRight:
            frame = rightWeightedRect(
                in: input.destinationVisibleFrame,
                currentWindow: input.windowFrame,
                height: halfHeight(input.destinationVisibleFrame),
                y: input.destinationVisibleFrame.minY
            )
        case .nextDisplay, .previousDisplay:
            frame = moveBetweenDisplays(input.windowFrame, from: input.sourceVisibleFrame, to: input.destinationVisibleFrame)
        case .nextThird:
            frame = third(afterCurrentWindowIn: input)
        case .previousThird:
            frame = third(beforeCurrentWindowIn: input)
        case .larger:
            frame = resized(input.windowFrame, in: input.destinationVisibleFrame, sizeOffset: 30)
        case .smaller:
            frame = resized(input.windowFrame, in: input.destinationVisibleFrame, sizeOffset: -30)
        case .undo, .redo:
            frame = input.windowFrame
        }

        return WindowCalculationResult(frame: frame, resolvedAction: input.action)
    }

    private enum VerticalEdge {
        case top
        case bottom
    }

    private func centered(_ windowFrame: CGRect, in visibleFrame: CGRect) -> CGRect {
        let width = min(windowFrame.width, visibleFrame.width)
        let height = min(windowFrame.height, visibleFrame.height)
        return CGRect(
            x: ((visibleFrame.width - width) / 2).rounded() + visibleFrame.minX,
            y: ((visibleFrame.height - height) / 2).rounded() + visibleFrame.minY,
            width: width,
            height: height
        )
    }

    private func halfWidth(_ visibleFrame: CGRect) -> CGFloat {
        floor(visibleFrame.width / 2)
    }

    private func halfHeight(_ visibleFrame: CGRect) -> CGFloat {
        floor(visibleFrame.height / 2)
    }

    private func upperY(_ visibleFrame: CGRect) -> CGFloat {
        visibleFrame.minY + halfHeight(visibleFrame) + visibleFrame.height.truncatingRemainder(dividingBy: 2)
    }

    private func leftWeightedRect(in visibleFrame: CGRect, currentWindow: CGRect, height: CGFloat, y: CGFloat) -> CGRect {
        let base = CGRect(x: visibleFrame.minX, y: y, width: halfWidth(visibleFrame), height: height)
        guard abs(currentWindow.midY - base.midY) <= 1 else { return base }

        let twoThirds = CGRect(
            x: visibleFrame.minX,
            y: y,
            width: floor(visibleFrame.width * 2 / 3),
            height: height
        )
        if rectCenteredWithinRect(base, currentWindow) {
            return twoThirds
        }
        if rectCenteredWithinRect(twoThirds, currentWindow) {
            return CGRect(x: visibleFrame.minX, y: y, width: floor(visibleFrame.width / 3), height: height)
        }
        return base
    }

    private func rightWeightedRect(in visibleFrame: CGRect, currentWindow: CGRect, height: CGFloat, y: CGFloat) -> CGRect {
        let baseWidth = halfWidth(visibleFrame)
        let base = CGRect(x: visibleFrame.minX + baseWidth, y: y, width: baseWidth, height: height)
        guard abs(currentWindow.midY - base.midY) <= 1 else { return base }

        let twoThirdsWidth = floor(visibleFrame.width * 2 / 3)
        let twoThirds = CGRect(
            x: visibleFrame.maxX - twoThirdsWidth,
            y: y,
            width: twoThirdsWidth,
            height: height
        )
        if rectCenteredWithinRect(base, currentWindow) {
            return twoThirds
        }
        if rectCenteredWithinRect(twoThirds, currentWindow) {
            let oneThirdWidth = floor(visibleFrame.width / 3)
            return CGRect(x: visibleFrame.maxX - oneThirdWidth, y: y, width: oneThirdWidth, height: height)
        }
        return base
    }

    private func verticalWeightedRect(in visibleFrame: CGRect, currentWindow: CGRect, edge: VerticalEdge) -> CGRect {
        let baseHeight = halfHeight(visibleFrame)
        let baseY = edge == .top ? upperY(visibleFrame) : visibleFrame.minY
        let base = CGRect(x: visibleFrame.minX, y: baseY, width: visibleFrame.width, height: baseHeight)
        guard abs(currentWindow.midX - base.midX) <= 1 else { return base }

        let twoThirdsHeight = floor(visibleFrame.height * 2 / 3)
        let twoThirdsY = edge == .top ? visibleFrame.maxY - twoThirdsHeight : visibleFrame.minY
        let twoThirds = CGRect(x: visibleFrame.minX, y: twoThirdsY, width: visibleFrame.width, height: twoThirdsHeight)
        if rectCenteredWithinRect(base, currentWindow) {
            return twoThirds
        }
        if rectCenteredWithinRect(twoThirds, currentWindow) {
            let oneThirdHeight = floor(visibleFrame.height / 3)
            let oneThirdY = edge == .top ? visibleFrame.maxY - oneThirdHeight : visibleFrame.minY
            return CGRect(x: visibleFrame.minX, y: oneThirdY, width: visibleFrame.width, height: oneThirdHeight)
        }
        return base
    }

    private func rectCenteredWithinRect(_ container: CGRect, _ rect: CGRect) -> Bool {
        container.contains(rect)
            && abs(container.midX - rect.midX) <= 1
            && abs(container.midY - rect.midY) <= 1
    }
}

private extension WindowPositionCalculator {
    func moveBetweenDisplays(_ windowFrame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        if rectFitsWithinRect(windowFrame, destination) {
            centered(windowFrame, in: destination)
        } else {
            destination
        }
    }

    func third(afterCurrentWindowIn input: WindowCalculationInput) -> CGRect {
        third(in: input.destinationVisibleFrame, currentWindow: input.windowFrame, offset: 1)
    }

    func third(beforeCurrentWindowIn input: WindowCalculationInput) -> CGRect {
        third(in: input.destinationVisibleFrame, currentWindow: input.windowFrame, offset: -1)
    }

    func third(in visibleFrame: CGRect, currentWindow: CGRect, offset: Int) -> CGRect {
        let thirds = thirdsFromVisibleFrame(visibleFrame)
        guard let currentIndex = thirds.firstIndex(where: { rectCenteredWithinRect($0, currentWindow) }) else {
            return thirds[0]
        }
        let targetIndex = (currentIndex + offset + thirds.count) % thirds.count
        return thirds[targetIndex]
    }

    func thirdsFromVisibleFrame(_ visibleFrame: CGRect) -> [CGRect] {
        let thirdWidth = floor(visibleFrame.width / 3)
        let thirdHeight = floor(visibleFrame.height / 3)
        var thirds: [CGRect] = []
        for index in 0..<3 {
            thirds.append(CGRect(
                x: visibleFrame.minX + thirdWidth * CGFloat(index),
                y: visibleFrame.minY,
                width: thirdWidth,
                height: visibleFrame.height
            ))
        }
        for index in 0..<3 {
            thirds.append(CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.maxY - thirdHeight * CGFloat(index + 1),
                width: visibleFrame.width,
                height: thirdHeight
            ))
        }
        return thirds
    }

    func resized(_ windowFrame: CGRect, in visibleFrame: CGRect, sizeOffset: CGFloat) -> CGRect {
        var resized = windowFrame
        resized.size.width += sizeOffset
        resized.origin.x -= floor(sizeOffset / 2)
        resized = adjustedAgainstLeftAndRightEdges(original: windowFrame, resized: resized, visibleFrame: visibleFrame)
        if resized.width >= visibleFrame.width {
            resized.size.width = visibleFrame.width
        }

        resized.size.height += sizeOffset
        resized.origin.y -= floor(sizeOffset / 2)
        resized = adjustedAgainstTopAndBottomEdges(original: windowFrame, resized: resized, visibleFrame: visibleFrame)
        if resized.height >= visibleFrame.height {
            resized.size.height = visibleFrame.height
            resized.origin.y = windowFrame.origin.y
        }

        if againstAllEdges(windowFrame, visibleFrame) && sizeOffset < 0 {
            resized.size.width = windowFrame.width + sizeOffset
            resized.origin.x = windowFrame.origin.x - floor(sizeOffset / 2)
            resized.size.height = windowFrame.height + sizeOffset
            resized.origin.y = windowFrame.origin.y - floor(sizeOffset / 2)
        }

        if resizedWindowRectIsTooSmall(resized, visibleFrame) {
            return windowFrame
        }
        return resized
    }

    func adjustedAgainstLeftAndRightEdges(original: CGRect, resized: CGRect, visibleFrame: CGRect) -> CGRect {
        var adjusted = resized
        if againstRightEdge(original, visibleFrame) {
            adjusted.origin.x = visibleFrame.maxX - adjusted.width
            if againstLeftEdge(original, visibleFrame) {
                adjusted.size.width = visibleFrame.width
            }
        }
        if againstLeftEdge(original, visibleFrame) {
            adjusted.origin.x = visibleFrame.minX
        }
        return adjusted
    }

    func adjustedAgainstTopAndBottomEdges(original: CGRect, resized: CGRect, visibleFrame: CGRect) -> CGRect {
        var adjusted = resized
        if againstTopEdge(original, visibleFrame) {
            adjusted.origin.y = visibleFrame.maxY - adjusted.height
            if againstBottomEdge(original, visibleFrame) {
                adjusted.size.height = visibleFrame.height
            }
        }
        if againstBottomEdge(original, visibleFrame) {
            adjusted.origin.y = visibleFrame.minY
        }
        return adjusted
    }

    func rectFitsWithinRect(_ rect: CGRect, _ container: CGRect) -> Bool {
        rect.width <= container.width && rect.height <= container.height
    }

    func againstEdge(_ gap: CGFloat) -> Bool {
        abs(gap) <= 5
    }

    func againstLeftEdge(_ windowFrame: CGRect, _ visibleFrame: CGRect) -> Bool {
        againstEdge(windowFrame.minX - visibleFrame.minX)
    }

    func againstRightEdge(_ windowFrame: CGRect, _ visibleFrame: CGRect) -> Bool {
        againstEdge(windowFrame.maxX - visibleFrame.maxX)
    }

    func againstTopEdge(_ windowFrame: CGRect, _ visibleFrame: CGRect) -> Bool {
        againstEdge(windowFrame.maxY - visibleFrame.maxY)
    }

    func againstBottomEdge(_ windowFrame: CGRect, _ visibleFrame: CGRect) -> Bool {
        againstEdge(windowFrame.minY - visibleFrame.minY)
    }

    func againstAllEdges(_ windowFrame: CGRect, _ visibleFrame: CGRect) -> Bool {
        againstLeftEdge(windowFrame, visibleFrame)
            && againstRightEdge(windowFrame, visibleFrame)
            && againstTopEdge(windowFrame, visibleFrame)
            && againstBottomEdge(windowFrame, visibleFrame)
    }

    func resizedWindowRectIsTooSmall(_ windowFrame: CGRect, _ visibleFrame: CGRect) -> Bool {
        let minimumWidth = floor(visibleFrame.width / 4)
        let minimumHeight = floor(visibleFrame.height / 4)
        return windowFrame.width <= minimumWidth || windowFrame.height <= minimumHeight
    }
}
