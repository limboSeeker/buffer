import AppKit
import ClipCore
import SwiftUI

/// Panel that takes keyboard focus without activating the app,
/// so the previously active app stays frontmost (needed for auto-paste).
final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PickerController: NSObject, NSWindowDelegate {
    private let panel: PickerPanel
    private let model: PickerModel
    private var keyMonitor: Any?

    init(store: HistoryStore, onChoose: @escaping (ClipItem) -> Void) {
        model = PickerModel(store: store)
        panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        model.onChoose = { [weak self] item in
            self?.close()
            onChoose(item)
        }

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { panel.standardWindowButton($0)?.isHidden = true }
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let hosting = NSHostingView(rootView: PickerView(model: model, store: store))
        hosting.sizingOptions = [] // window size is fixed; don't let SwiftUI grow it by the titlebar height
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: 460, height: 500))
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        panel.isVisible ? close() : show()
    }

    func show() {
        model.query = ""
        model.selection = 0
        positionNearMouse()
        panel.makeKeyAndOrderFront(nil)
        model.focusToken += 1
        installKeyMonitor()
    }

    func close() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    /// Debug helper: writes the panel contents to PNG and logs focus state.
    func snapshot(to url: URL) {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        NSLog("Buffer: snapshot visible=%d key=%d firstResponder=%@",
              panel.isVisible, panel.isKeyWindow, String(describing: panel.firstResponder.map { type(of: $0) }))
        close()
    }

    private func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - 20, y: mouse.y - size.height + 20)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 125: model.move(1); return true                       // ↓
        case 126: model.move(-1); return true                      // ↑
        case 36, 76: model.choose(index: model.selection); return true // return / enter
        case 53: close(); return true                              // esc
        case 51 where command: model.deleteSelected(); return true // ⌘⌫
        default: break
        }
        guard command, let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if let digit = Int(chars), (1...9).contains(digit) {
            model.choose(index: digit - 1)
            return true
        }
        if chars == "p" || chars == "з" {
            model.togglePinSelected()
            return true
        }
        return false
    }
}
