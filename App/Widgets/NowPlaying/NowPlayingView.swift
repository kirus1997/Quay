import AppKit
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var model: NowPlayingModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 2) {
                    transport("backward.fill", label: "Previous track", action: .previous)
                    transport(model.track?.status == .playing ? "pause.fill" : "play.fill", label: model.track?.status == .playing ? "Pause" : "Play", action: .toggle)
                    transport("forward.fill", label: "Next track", action: .next)
                    if model.automationDenied {
                        Button("Allow") {
                            SystemSettingsLink.open(.automation)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Allow Quay to control Spotify and Music in System Settings")
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 250, alignment: .leading)
        .background(WidgetPlate())
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        guard let track = model.track, !track.title.isEmpty else { return "Nothing playing" }
        return track.title
    }

    private var subtitle: String {
        guard let track = model.track, !track.title.isEmpty else {
            return model.automationDenied ? "Automation is off" : "Spotify or Music"
        }
        if track.artist.isEmpty { return track.source.displayName }
        return "\(track.artist) · \(track.source.displayName)"
    }

    @ViewBuilder
    private var artwork: some View {
        let image = model.artwork.flatMap { NSImage(data: $0) }
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.9))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(monogram)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var monogram: String {
        let source = title == "Nothing playing" ? "Q" : title
        return String(source.prefix(1)).uppercased()
    }

    private func transport(_ symbol: String, label: String, action: TransportAction) -> some View {
        Button {
            model.perform(action)
        } label: {
            Image(systemName: symbol)
                .frame(width: 22, height: 18)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

struct WidgetPlate: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.16))
    }
}
