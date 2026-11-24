import XCTest
@testable import ClipCore

final class HistoryStoreTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testNewestFirst() {
        let store = HistoryStore(directory: dir)
        store.addText("a")
        store.addText("b")
        XCTAssertEqual(store.items.map(\.text), ["b", "a"])
    }

    func testDuplicateMovesToTopWithoutCopy() {
        let store = HistoryStore(directory: dir)
        store.addText("a")
        store.addText("b")
        store.addText("a")
        XCTAssertEqual(store.items.map(\.text), ["a", "b"])
    }

    func testBlankIgnored() {
        let store = HistoryStore(directory: dir)
        XCTAssertNil(store.addText("  \n\t"))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testLimitDropsOldestUnpinned() {
        let store = HistoryStore(directory: dir, maxItems: 3)
        let first = store.addText("1")!
        store.togglePin(first.id)
        store.addText("2")
        store.addText("3")
        store.addText("4")
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(Set(store.items.compactMap(\.text)), ["1", "3", "4"])
    }

    func testClearKeepsPinned() {
        let store = HistoryStore(directory: dir)
        let keep = store.addText("keep")!
        store.addText("drop")
        store.togglePin(keep.id)
        store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.text), ["keep"])
    }

    func testSearchPinnedFirstAndCaseInsensitive() {
        let store = HistoryStore(directory: dir)
        let pinned = store.addText("Привет мир")!
        store.addText("привет снова")
        store.addText("другое")
        store.togglePin(pinned.id)
        XCTAssertEqual(store.search("ПРИВЕТ").map(\.text), ["Привет мир", "привет снова"])
        XCTAssertEqual(store.search("").first?.text, "Привет мир")
    }

    func testPromote() {
        let store = HistoryStore(directory: dir)
        let a = store.addText("a")!
        store.addText("b")
        store.promote(a.id)
        XCTAssertEqual(store.items.first?.id, a.id)
    }

    func testPersistenceRoundTrip() {
        let store = HistoryStore(directory: dir)
        let a = store.addText("a")!
        store.togglePin(a.id)
        store.addImage(png: Data([1, 2, 3]))
        let reloaded = HistoryStore(directory: dir)
        XCTAssertEqual(reloaded.items.count, 2)
        XCTAssertEqual(reloaded.items.last?.pinned, true)
        let image = reloaded.items.first!
        XCTAssertEqual(image.kind, .image)
        XCTAssertTrue(FileManager.default.fileExists(atPath: reloaded.imageURL(for: image)!.path))
    }

    func testRemovingImageDeletesFile() {
        let store = HistoryStore(directory: dir)
        let image = store.addImage(png: Data([9, 9]))!
        let url = store.imageURL(for: image)!
        store.remove(image.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testPreviewCollapsesLines() {
        let item = ClipItem(kind: .text, text: "line1\n\n  line2  ", hash: "x")
        XCTAssertEqual(item.preview(), "line1 ⏎ line2")
    }
}
