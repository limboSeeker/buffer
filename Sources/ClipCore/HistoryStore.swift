import Combine
import CryptoKit
import Foundation

/// Clipboard history: dedupe, size limit, pinning, search and JSON persistence.
public final class HistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    public let directory: URL
    public var maxItems: Int

    private var historyURL: URL { directory.appendingPathComponent("history.json") }
    private var imagesDir: URL { directory.appendingPathComponent("images", isDirectory: true) }

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Buffer", isDirectory: true)
    }

    public init(directory: URL, maxItems: Int = 200) {
        self.directory = directory
        self.maxItems = maxItems
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Adding

    @discardableResult
    public func addText(_ text: String, date: Date = Date()) -> ClipItem? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let hash = "t:" + Self.sha256(Data(text.utf8))
        return insert(hash: hash, date: date) {
            ClipItem(kind: .text, text: text, hash: hash, date: date)
        }
    }

    @discardableResult
    public func addImage(png: Data, date: Date = Date()) -> ClipItem? {
        guard !png.isEmpty else { return nil }
        let digest = Self.sha256(png)
        let hash = "i:" + digest
        return insert(hash: hash, date: date) {
            let name = String(digest.prefix(32)) + ".png"
            try? png.write(to: imagesDir.appendingPathComponent(name), options: .atomic)
            return ClipItem(kind: .image, imageFile: name, hash: hash, date: date)
        }
    }

    private func insert(hash: String, date: Date, make: () -> ClipItem) -> ClipItem {
        if let idx = items.firstIndex(where: { $0.hash == hash }) {
            var existing = items.remove(at: idx)
            existing.date = date
            items.insert(existing, at: 0)
            save()
            return existing
        }
        let item = make()
        items.insert(item, at: 0)
        trim()
        save()
        return item
    }

    // MARK: - Editing

    public func promote(_ id: UUID, date: Date = Date()) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: idx)
        item.date = date
        items.insert(item, at: 0)
        save()
    }

    public func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        save()
    }

    public func remove(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        deleteFile(of: items.remove(at: idx))
        save()
    }

    /// Removes everything except pinned items.
    public func clearUnpinned() {
        items.filter { !$0.pinned }.forEach(deleteFile)
        items.removeAll { !$0.pinned }
        save()
    }

    private func trim() {
        while items.count > maxItems, let idx = items.lastIndex(where: { !$0.pinned }) {
            deleteFile(of: items.remove(at: idx))
        }
    }

    // MARK: - Querying

    /// Pinned items first, then the rest by recency. Images are hidden while a query is typed.
    public func search(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let matched = q.isEmpty ? items : items.filter { $0.text?.localizedCaseInsensitiveContains(q) ?? false }
        return matched.filter(\.pinned) + matched.filter { !$0.pinned }
    }

    public func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesDir.appendingPathComponent($0) }
    }

    // MARK: - Persistence

    private func deleteFile(of item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        // Another item never shares the file (dedupe by hash), so it is safe to delete.
        try? FileManager.default.removeItem(at: url)
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
