import AppKit
import SwiftUI

/// Shows an AppKit popover from a dock slot. SwiftUI's popover is unreliable on a non-activating panel.
struct AnchorPopover<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    var size: CGSize
    var content: Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            isPresented: isPresented,
            size: size,
            content: content,
            relativeTo: nsView,
            onDismiss: { isPresented = false }
        )
    }

    final class Coordinator: NSObject, NSPopoverDelegate {
        private var popover: NSPopover?
        private var hosting: NSHostingController<Content>?
        var onDismiss: (() -> Void)?

        func update(
            isPresented: Bool,
            size: CGSize,
            content: Content,
            relativeTo view: NSView,
            onDismiss: @escaping () -> Void
        ) {
            self.onDismiss = onDismiss
            if isPresented {
                if popover == nil {
                    let host = NSHostingController(rootView: content)
                    let pop = NSPopover()
                    pop.behavior = .transient
                    pop.animates = true
                    pop.contentSize = NSSize(width: size.width, height: size.height)
                    pop.contentViewController = host
                    pop.delegate = self
                    hosting = host
                    popover = pop
                } else {
                    hosting?.rootView = content
                    popover?.contentSize = NSSize(width: size.width, height: size.height)
                }
                if let popover, !popover.isShown, view.window != nil, view.bounds.width > 0 || view.bounds.height > 0 {
                    popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
                }
            } else if let popover {
                popover.delegate = nil
                popover.performClose(nil)
                self.popover = nil
                hosting = nil
            }
        }

        func popoverDidClose(_ notification: Notification) {
            popover = nil
            hosting = nil
            onDismiss?()
        }
    }
}
