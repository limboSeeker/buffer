import AppKit
import Carbon
import ClipCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = HistoryStore(directory: HistoryStore.defaultDirectory)
    private var watcher: PasteboardWatcher!
    private var picker: PickerController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!
    private let onboarding = OnboardingController()

    private static let autoPasteKey = "autoPaste"
    private static let menuItemsCount = 15

    private var autoPaste: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoPasteKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoPasteKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.autoPasteKey: true])
        onboarding.onCopyOnly = { [weak self] in self?.autoPaste = false }
        let trusted = Paster.isTrusted(prompt: false)
        Log.write("launch: accessibility trusted=\(trusted) autoPaste=\(autoPaste)")
        if autoPaste && !trusted {
            onboarding.show()
        }

        watcher = PasteboardWatcher(store: store)
        watcher.start()

        picker = PickerController(store: store) { [weak self] item in self?.choose(item) }

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)) { [weak self] in
            self?.picker.toggle()
        }
        NSLog("Buffer: ⌥V hotkey %@", hotKey == nil ? "FAILED to register (already taken?)" : "registered")
        enableLaunchAtLoginOnFirstRun()

        // Debug: BUFFER_SNAPSHOT=/path.png opens the picker and saves a snapshot of it.
        if let path = ProcessInfo.processInfo.environment["BUFFER_SNAPSHOT"] {
            picker.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.picker.snapshot(to: URL(fileURLWithPath: path))
            }
        }
        if let path = ProcessInfo.processInfo.environment["BUFFER_SNAPSHOT_ONBOARDING"] {
            onboarding.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.onboarding.snapshot(to: URL(fileURLWithPath: path))
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Буфер")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Turns launch-at-login on once; afterwards the menu toggle is the user's choice.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "loginItemConfigured"
        if !UserDefaults.standard.bool(forKey: key) {
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: key)
            } catch {
                NSLog("Buffer: launch at login failed: %@", error.localizedDescription)
            }
        }
        NSLog("Buffer: launch at login status=%d (1 = enabled)", SMAppService.mainApp.status.rawValue)
    }

    // MARK: - Choosing

    private func choose(_ item: ClipItem) {
        watcher.write(item)
        store.promote(item.id)
        let trusted = Paster.isTrusted(prompt: false)
        Log.write("choose: kind=\(item.kind) pasteboardTypes=\(NSPasteboard.general.types?.count ?? 0) autoPaste=\(autoPaste) trusted=\(trusted) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil") active=\(NSApp.isActive)")
        // The picker panel never activates Buffer, so ⌘V lands in the app (and text field) that had focus.
        guard autoPaste else { return }
        guard trusted else {
            // Don't fail silently: explain what is missing and how to grant it.
            onboarding.show()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Paster.paste() }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let show = NSMenuItem(title: "Открыть историю", action: #selector(showPicker), keyEquivalent: "v")
        show.keyEquivalentModifierMask = [.option]
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())

        let recent = store.search("").prefix(Self.menuItemsCount)
        if recent.isEmpty {
            let empty = NSMenuItem(title: "История пуста", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for item in recent {
            let entry = NSMenuItem(title: item.preview(maxLength: 60), action: #selector(chooseFromMenu(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = item.id
            entry.toolTip = item.kind == .text ? String((item.text ?? "").prefix(500)) : nil
            if item.pinned {
                entry.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)
            } else if item.kind == .image, let url = store.imageURL(for: item), let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 16, height: 16)
                entry.image = image
            }
            menu.addItem(entry)
        }

        menu.addItem(.separator())

        let paste = NSMenuItem(title: "Вставлять сразу после выбора", action: #selector(toggleAutoPaste), keyEquivalent: "")
        paste.target = self
        paste.state = autoPaste ? .on : .off
        menu.addItem(paste)

        if autoPaste && !Paster.isTrusted(prompt: false) {
            let grant = NSMenuItem(title: "Разрешить вставку…", action: #selector(showOnboarding), keyEquivalent: "")
            grant.target = self
            grant.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(grant)
        }

        let login = NSMenuItem(title: "Запускать при входе", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let clear = NSMenuItem(title: "Очистить историю…", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func showPicker() {
        picker.show()
    }

    @objc private func chooseFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        choose(item)
    }

    @objc private func toggleAutoPaste() {
        autoPaste.toggle()
        if autoPaste && !Paster.isTrusted(prompt: false) { onboarding.show() }
    }

    @objc private func showOnboarding() {
        onboarding.show()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(title: "Не удалось изменить автозапуск", text: error.localizedDescription)
        }
    }

    @objc private func clearHistory() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Очистить историю?"
        alert.informativeText = "Закреплённые элементы останутся."
        alert.addButton(withTitle: "Очистить")
        alert.addButton(withTitle: "Отмена")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearUnpinned()
        }
    }

    private func showAlert(title: String, text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
