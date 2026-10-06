import AppKit

enum DockWindowChrome {
    static func apply(_ window: NSPanel) {
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isExcludedFromWindowsMenu = true
        window.animationBehavior = .none
        window.ignoresMouseEvents = false
    }
}

/// Borderless panel pinned above normal windows on every Space.
/// It does not activate the app, so clicking an icon still leaves the current app in front after launch.
final class DockPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        DockWindowChrome.apply(self)
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Always-on hit target along the bottom edge of the main display. Mouse tracking lives here, so the dock does not need a global event monitor.
final class DockEdgeStripPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 3),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        DockWindowChrome.apply(self)
        level = .statusBar
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class DockHoverView: NSView {
    var onEntered: (() -> Void)?
    var onExited: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .assumeInside],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onExited?()
    }
}

final class DockEdgeStripView: DockHoverView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 1.5
        setAccessibilityRole(.button)
        setAccessibilityLabel("Show Quay")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }
}
