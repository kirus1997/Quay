import AppKit
import SwiftUI

@MainActor
final class DockPanelController: NSObject {
    let panel: DockPanel
    private var lastSize: CGSize = .zero
    private var screenObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    override init() {
        panel = DockPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 140))
        super.init()
        installContent()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.placeCurrent()
            }
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.panel.orderFrontRegardless()
            }
        }
    }

    func show() {
        panel.orderFrontRegardless()
        placeCurrent()
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
        panel.contentView = host
    }

    private func resize(to size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        guard abs(size.width - lastSize.width) > 0.5 || abs(size.height - lastSize.height) > 0.5 else { return }
        lastSize = size
        place(size: size)
    }

    private func placeCurrent() {
        let size = lastSize == .zero ? CGSize(width: 420, height: 140) : lastSize
        place(size: size)
    }

    private func place(size: CGSize) {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let width = min(size.width, max(120, visible.width - 16))
        let height = size.height
        let origin = NSPoint(
            x: visible.midX - width / 2,
            y: visible.minY + 6
        )
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}
