import SwiftUI

struct CollectionMenu: View {
    var collection: AppCollection
    var onOpen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(collection.name)
                .font(.headline)
                .lineLimit(1)
            if collection.apps.isEmpty {
                Text("No apps in this collection yet. Add some in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(collection.apps) { app in
                            Button {
                                onOpen(app.path)
                            } label: {
                                HStack(spacing: 8) {
                                    AppIconView(path: app.path, size: 24)
                                    Text(app.name)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(app.name)")
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
    }
}
