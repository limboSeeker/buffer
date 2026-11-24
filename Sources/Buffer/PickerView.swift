import AppKit
import ClipCore
import SwiftUI

final class PickerModel: ObservableObject {
    @Published var query = "" { didSet { selection = 0 } }
    @Published var selection = 0
    @Published var focusToken = 0

    let store: HistoryStore
    var onChoose: (ClipItem) -> Void = { _ in }

    private let thumbnails = NSCache<NSString, NSImage>()

    init(store: HistoryStore) {
        self.store = store
    }

    var results: [ClipItem] { store.search(query) }

    var selectedItem: ClipItem? {
        let list = results
        return list.indices.contains(selection) ? list[selection] : nil
    }

    func move(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    func choose(index: Int) {
        let list = results
        guard list.indices.contains(index) else { return }
        onChoose(list[index])
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        store.remove(item.id)
        selection = min(selection, max(results.count - 1, 0))
    }

    func togglePinSelected() {
        guard let item = selectedItem else { return }
        store.togglePin(item.id)
        selection = results.firstIndex(where: { $0.id == item.id }) ?? 0
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        guard let url = store.imageURL(for: item) else { return nil }
        let key = url.lastPathComponent as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        thumbnails.setObject(image, forKey: key)
        return image
    }
}

struct PickerView: View {
    @ObservedObject var model: PickerModel
    @ObservedObject var store: HistoryStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = model.results
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search history", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if results.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text(model.query.isEmpty ? "History is empty. Copy something." : "Nothing found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                ClipRow(item: item, index: index, selected: index == model.selection,
                                        thumbnail: item.kind == .image ? model.thumbnail(for: item) : nil)
                                    .id(item.id)
                                    .onTapGesture { model.choose(index: index) }
                                    .contextMenu {
                                        Button(item.pinned ? "Unpin" : "Pin") { store.togglePin(item.id) }
                                        Button("Delete", role: .destructive) { store.remove(item.id) }
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: model.selection) { _, newValue in
                        guard results.indices.contains(newValue) else { return }
                        proxy.scrollTo(results[newValue].id)
                    }
                }
            }

            Divider()

            Text("↩ choose   ↑↓ move   ⌘1–9 quick pick   ⌘P pin   ⌘⌫ delete   esc")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .ignoresSafeArea() // the hidden titlebar must not push content down
        .onReceive(model.$focusToken) { _ in
            DispatchQueue.main.async { searchFocused = true }
        }
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let selected: Bool
    let thumbnail: NSImage?

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "en_US")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    Image(systemName: item.kind == .image ? "photo" : "text.alignleft")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview())
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if item.pinned {
                Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(.orange)
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.accentColor.opacity(0.28) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let time = Self.relative.localizedString(for: item.date, relativeTo: Date())
        if item.kind == .text, let text = item.text {
            return String(format: "%@ · %d chars", time, text.count)
        }
        return time
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
