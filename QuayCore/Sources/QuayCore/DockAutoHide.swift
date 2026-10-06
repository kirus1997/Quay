import Foundation

public struct DockRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func contains(x: Double, y: Double) -> Bool {
        x >= self.x && x < self.x + width && y >= self.y && y < self.y + height
    }
}

/// Geometry for the dock and the thin bottom-edge hit strip. Screen coordinates, origin at the bottom left.
public enum DockAutoHideLayout {
    public static let stripThickness: Double = 3
    public static let hideDelay: TimeInterval = 0.6
    public static let slideDuration: TimeInterval = 0.28
    public static let restingGap: Double = 6

    public static func restingFrame(
        contentWidth: Double,
        contentHeight: Double,
        visibleMinX: Double,
        visibleMinY: Double,
        visibleWidth: Double
    ) -> DockRect {
        let width = min(contentWidth, max(120, visibleWidth - 16))
        let x = visibleMinX + (visibleWidth - width) / 2
        return DockRect(x: x, y: visibleMinY + restingGap, width: width, height: contentHeight)
    }

    /// The dock panel sits fully below the display so it cannot catch clicks. The strip is the hit target.
    public static func concealedFrame(resting: DockRect, screenMinY: Double) -> DockRect {
        DockRect(
            x: resting.x,
            y: screenMinY - resting.height - 1,
            width: resting.width,
            height: resting.height
        )
    }

    public static func stripFrame(matching dock: DockRect, screenMinY: Double) -> DockRect {
        DockRect(x: dock.x, y: screenMinY, width: dock.width, height: stripThickness)
    }
}

public enum DockAutoHideEffect: Equatable, Sendable {
    case none
    case reveal
    case conceal
    case pinVisible
}

public enum DockAutoHideEvent: Equatable, Sendable {
    case pointerEntered
    case pointerExited
    case popoverBegan
    case popoverEnded
    case hideDelayFired
    case setAutoHides(Bool)
    case showRequested
}

public struct DockAutoHideState: Equatable, Sendable {
    public var autoHides: Bool
    public var revealed: Bool
    public var pointerInside: Bool
    public var popoverCount: Int
    public var hideScheduled: Bool

    public init(
        autoHides: Bool = true,
        revealed: Bool = false,
        pointerInside: Bool = false,
        popoverCount: Int = 0,
        hideScheduled: Bool = false
    ) {
        self.autoHides = autoHides
        self.revealed = revealed
        self.pointerInside = pointerInside
        self.popoverCount = popoverCount
        self.hideScheduled = hideScheduled
    }

    public mutating func send(_ event: DockAutoHideEvent) -> DockAutoHideEffect {
        switch event {
        case .pointerEntered:
            pointerInside = true
            hideScheduled = false
            return showBecausePointerOrPopover()
        case .pointerExited:
            pointerInside = false
            return scheduleHideIfIdle()
        case .popoverBegan:
            popoverCount += 1
            hideScheduled = false
            return showBecausePointerOrPopover()
        case .popoverEnded:
            popoverCount = max(0, popoverCount - 1)
            return scheduleHideIfIdle()
        case .hideDelayFired:
            guard hideScheduled else { return .none }
            hideScheduled = false
            guard autoHides, popoverCount == 0, !pointerInside else { return .none }
            revealed = false
            return .conceal
        case .setAutoHides(let enabled):
            autoHides = enabled
            hideScheduled = false
            if !enabled {
                revealed = true
                return .pinVisible
            }
            if pointerInside || popoverCount > 0 {
                revealed = true
                return .reveal
            }
            revealed = false
            return .conceal
        case .showRequested:
            revealed = true
            if !autoHides {
                hideScheduled = false
                return .pinVisible
            }
            if pointerInside || popoverCount > 0 {
                hideScheduled = false
                return .reveal
            }
            hideScheduled = true
            return .reveal
        }
    }

    private mutating func showBecausePointerOrPopover() -> DockAutoHideEffect {
        if !autoHides {
            let wasHidden = !revealed
            revealed = true
            return wasHidden ? .pinVisible : .none
        }
        if revealed { return .none }
        revealed = true
        return .reveal
    }

    private mutating func scheduleHideIfIdle() -> DockAutoHideEffect {
        guard autoHides, popoverCount == 0, !pointerInside, revealed else { return .none }
        hideScheduled = true
        return .none
    }
}
