import SwiftUI

struct DockSizePreference: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct DockBarView: View {
    @EnvironmentObject private var dock: DockModel
    var onResize: (CGSize) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: QuayActions.openSettings) {
                Image("MenuBarMark")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Quay Settings")
            .accessibilityLabel("Quay Settings")

            ForEach(dock.configuration.slots) { slot in
                DockSlotView(slot: slot)
            }

            if dock.configuration.slots.isEmpty {
                Text("Add apps in Settings")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
        }
        .padding(10)
        .background(DockSurface())
        .padding(24)
        .fixedSize()
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: DockSizePreference.self, value: proxy.size)
            }
        }
        .onPreferenceChange(DockSizePreference.self, perform: onResize)
    }
}

private struct DockSurface: View {
    var body: some View {
        ZStack {
            VisualEffectBackground(cornerRadius: 28)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
    }
}

private struct DockSlotView: View {
    var slot: DockSlot

    var body: some View {
        switch slot.content {
        case .app(let app):
            Button {
                AppLauncher.open(app.path)
            } label: {
                AppIconView(path: app.path)
            }
            .buttonStyle(.plain)
            .modifier(HoverLift())
            .help(app.name)
            .accessibilityLabel("Open \(app.name)")
        case .collection(let collection):
            CollectionSlotView(collection: collection)
        case .widget(let kind):
            widget(kind)
        }
    }

    @ViewBuilder
    private func widget(_ kind: WidgetKind) -> some View {
        switch kind {
        case .nowPlaying:
            NowPlayingView()
        case .timer:
            TimerWidgetView()
        case .upcomingEvents:
            EventsWidgetView()
        }
    }
}

private struct CollectionSlotView: View {
    var collection: AppCollection
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            VStack(spacing: 3) {
                CollectionMark(collection: collection)
                Text(collection.name)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .frame(width: 64)
            }
        }
        .buttonStyle(.plain)
        .modifier(HoverLift())
        .help(collection.name)
        .accessibilityLabel("Open collection \(collection.name)")
        .background(
            AnchorPopover(
                isPresented: $isPresented,
                size: CGSize(width: 280, height: collection.apps.isEmpty ? 120 : min(320, 72 + CGFloat(collection.apps.count) * 36)),
                content: CollectionMenu(collection: collection) { path in
                    AppLauncher.open(path)
                    isPresented = false
                }
            )
        )
    }
}

private struct CollectionMark: View {
    var collection: AppCollection

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.14))
            if collection.apps.isEmpty {
                Text(monogram)
                    .font(.system(size: 16, weight: .semibold))
            } else {
                LazyVGrid(columns: [GridItem(.fixed(16), spacing: 2), GridItem(.fixed(16), spacing: 2)], spacing: 2) {
                    ForEach(collection.apps.prefix(4)) { app in
                        AppIconView(path: app.path, size: 16)
                    }
                }
            }
        }
        .frame(width: 44, height: 44)
        .overlay(alignment: .bottomTrailing) {
            if collection.apps.count > 4 {
                Text("\(collection.apps.count)")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor))
                    .offset(x: 4, y: 4)
            }
        }
    }

    private var monogram: String {
        String(collection.name.prefix(1)).uppercased()
    }
}
