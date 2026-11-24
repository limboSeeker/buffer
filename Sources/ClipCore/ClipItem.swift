import Foundation

public enum ClipKind: String, Codable {
    case text
    case image
}

public struct ClipItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var kind: ClipKind
    public var text: String?
    public var imageFile: String?
    public var hash: String
    public var date: Date
    public var pinned: Bool

    public init(id: UUID = UUID(), kind: ClipKind, text: String? = nil, imageFile: String? = nil,
                hash: String, date: Date = Date(), pinned: Bool = false) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageFile = imageFile
        self.hash = hash
        self.date = date
        self.pinned = pinned
    }

    /// Single-line preview for lists and menus.
    public func preview(maxLength: Int = 200) -> String {
        switch kind {
        case .image:
            return "Image"
        case .text:
            let collapsed = (text ?? "")
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ⏎ ")
            return collapsed.count > maxLength ? String(collapsed.prefix(maxLength)) + "…" : collapsed
        }
    }
}
