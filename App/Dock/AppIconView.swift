import AppKit
import SwiftUI

struct AppIconView: View {
    var path: String
    var size: CGFloat = 44

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .opacity(FileManager.default.fileExists(atPath: path) ? 1 : 0.45)
    }
}

struct HoverLift: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.08 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: hovering)
            .onHover { hovering = $0 }
    }
}
