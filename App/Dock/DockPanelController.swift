import AppKit
import QuartzCore
import QuayCore
import SwiftUI

@MainActor
final class DockPanelController: NSObject {
    let panel: DockPanel
    private let strip = DockEdgeStripPanel()
    private let stripView = DockEdgeStripView(frame: NSRect(x: 0, y: 0, width: 200, height: 3))
    private var state = DockAutoHideState()
    private var lastSize: CGSize = .zero
    private var started = false
    private var animationToken = 0
    private var hideWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    override init() {
        panel = DockPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 140))
        super.init()
        installContent()
        installStrip()
        observe()
    }

    /// Places the dock for the saved auto-hide setting. Launch leaves it concealed when auto-hide is on.
    func start() {
        let enabled = QuayRuntime.shared.dock.configuration.autoHides
        state = DockAutoHideState(autoHides: enabled, revealed: !enabled)
        started = true
        if enabled {
            conceal(animated: false)
        } else {
            pin(animated: false)
        }
    }

    /// Menu-bar “Show Dock”. Reveals immediately, then hides again after the usual delay if the pointer stays away.
    func show() {
        handle(.showRequested)
    }

    func noteConfigurationChanged() {
        let enabled = QuayRuntime.shared.dock.configuration.autoHides
        guard enabled != state.autoHides else { return }
        handle(.setAutoHides(enabled))
    }

    func popoverBegan() {
        handle(.popoverBegan)
    }

    func popoverEnded() {
        handle(.popoverEnded)
    }

    private func handle(_ event: DockAutoHideEvent) {
        let wasScheduled = state.hideScheduled
        let effect = state.send(event)
        if !state.hideScheduled {
            cancelHideTimer()
        } else if event == .showRequested || !wasScheduled {
            armHideTimer()
        }
        switch effect {
        case .none:
            break
        case .reveal:
            reveal(animated: true)
        case .conceal:
            conceal(animated: true)
        case .pinVisible:
            pin(animated: true)
        }
    }

    private func installContent() {
        let runtime = QuayRuntime.shared
        let root = DockBarView { [weak self] size in
            self?.resize(to: size)
        }
        .environmentObject(runtime.dock)
        .environmentObject(runtime.timers)
        .environmentObject(runtime.nowPlaying)
        .environmentObject(runtime.events)

        let host = NSHostingView(rootView: root)
        host.sizingOptions = [.intrinsicContentSize]
        host.autoresizingMask = [.width, .height]
        if let layer = host.layer {
            layer.backgroundColor = NSColor.clear.cgColor
        } else {
            host.wantsLayer = true
            host.layer?.backgroundColor = NSColor.clear.cgColor
        }

        let hover = DockHoverView(frame: panel.frame)
        hover.autoresizingMask = [.width, .height]
        hover.onEntered = { [weak self] in
            self?.handle(.pointerEntered)
        }
        hover.onExited = { [weak self] in
            self?.pointerMaybeExited()
        }
        panel.contentView = hover
        host.frame = hover.bounds
        hover.addSubview(host)
    }

    private func installStrip() {
        stripView.onEntered = { [weak self] in
            self?.handle(.pointerEntered)
        }
        stripView.onExited = { [weak self] in
            self?.pointerMaybeExited()
        }
        strip.contentView = stripView
    }

    private func observe() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reposition(animated: false)
            }
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.keepOrderedFront()
            }
        }
    }

    private func resize(to size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        guard abs(size.width - lastSize.width) > 0.5 || abs(size.height - lastSize.height) > 0.5 else { return }
        lastSize = size
        guard started else { return }
        reposition(animated: false)
    }

    private func reposition(animated: Bool) {
        guard started else { return }
        if !state.autoHides {
            pin(animated: animated)
        } else if state.revealed {
            reveal(animated: animated)
        } else {
            conceal(animated: animated)
        }
    }

    private func reveal(animated: Bool) {
        guard let screen = primaryScreen else { return }
        let frames = frames(on: screen)
        panel.level = .statusBar
        strip.level = .statusBar
        placeStrip(frames.strip)
        if !panel.isVisible {
            panel.setFrame(nsRect(frames.concealed), display: false)
        }
        strip.orderFrontRegardless()
        panel.orderFrontRegardless()
        setDockFrame(nsRect(frames.resting), animated: animated)
    }

    private func conceal(animated: Bool) {
        guard let screen = primaryScreen else { return }
        let frames = frames(on: screen)
        panel.level = .statusBar
        strip.level = .statusBar
        placeStrip(frames.strip)
        // Keep the panel ordered in, fully below the display, so SwiftUI can measure it. The strip is the only on-screen hit target.
        let wasVisible = panel.isVisible
        if !wasVisible {
            panel.setFrame(nsRect(frames.concealed), display: false)
        }
        panel.orderFrontRegardless()
        strip.orderFrontRegardless()
        setDockFrame(nsRect(frames.concealed), animated: animated && wasVisible)
    }

    private func pin(animated: Bool) {
        guard let screen = primaryScreen else { return }
        let frames = frames(on: screen)
        strip.orderOut(nil)
        panel.level = .floating
        panel.orderFrontRegardless()
        setDockFrame(nsRect(frames.resting), animated: animated)
    }

    private func keepOrderedFront() {
        if state.autoHides {
            strip.orderFrontRegardless()
        }
        if state.revealed || !state.autoHides {
            panel.orderFrontRegardless()
        }
    }

    private func pointerMaybeExited() {
        let mouse = NSEvent.mouseLocation
        if panel.isVisible, panel.frame.contains(mouse) { return }
        if strip.isVisible, strip.frame.contains(mouse) { return }
        handle(.pointerExited)
    }

    private func setDockFrame(_ frame: NSRect, animated: Bool) {
        animationToken += 1
        let token = animationToken
        let unchanged = nearlyEqual(panel.frame, frame)
        if !animated || unchanged {
            panel.setFrame(frame, display: true)
            dockAnimationFinished(token: token)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DockAutoHideLayout.slideDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 1.15, 0.32, 1)
            self.panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.dockAnimationFinished(token: token)
            }
        }
    }

    private func dockAnimationFinished(token: Int) {
        guard token == animationToken else { return }
        guard state.autoHides, !state.revealed else { return }
        strip.orderFrontRegardless()
        if strip.frame.contains(NSEvent.mouseLocation) {
            handle(.pointerEntered)
        }
    }

    private func armHideTimer() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.hideDelayFired()
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + DockAutoHideLayout.hideDelay, execute: work)
    }

    private func cancelHideTimer() {
        hideWork?.cancel()
        hideWork = nil
    }

    private func hideDelayFired() {
        hideWork = nil
        guard state.hideScheduled else { return }
        handle(.hideDelayFired)
    }

    private var primaryScreen: NSScreen? {
        NSScreen.screens.first
    }

    private func frames(on screen: NSScreen) -> (resting: DockRect, concealed: DockRect, strip: DockRect) {
        let size = lastSize == .zero ? CGSize(width: 420, height: 140) : lastSize
        let visible = screen.visibleFrame
        let resting = DockAutoHideLayout.restingFrame(
            contentWidth: Double(size.width),
            contentHeight: Double(size.height),
            visibleMinX: Double(visible.minX),
            visibleMinY: Double(visible.minY),
            visibleWidth: Double(visible.width)
        )
        return (
            resting,
            DockAutoHideLayout.concealedFrame(resting: resting, screenMinY: Double(screen.frame.minY)),
            DockAutoHideLayout.stripFrame(matching: resting, screenMinY: Double(screen.frame.minY))
        )
    }

    private func placeStrip(_ rect: DockRect) {
        strip.setFrame(nsRect(rect).integral, display: true)
        if !strip.isVisible {
            strip.orderFrontRegardless()
        }
        stripView.updateTrackingAreas()
    }

    private func nsRect(_ rect: DockRect) -> NSRect {
        NSRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private func nearlyEqual(_ lhs: NSRect, _ rhs: NSRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 0.5
            && abs(lhs.origin.y - rhs.origin.y) < 0.5
            && abs(lhs.width - rhs.width) < 0.5
            && abs(lhs.height - rhs.height) < 0.5
    }
}
