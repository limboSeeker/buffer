import AppKit
import SwiftUI

final class OnboardingModel: ObservableObject {
    @Published var trusted = false
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let openSettings: () -> Void
    let copyOnly: () -> Void
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 30))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buffer запущен").font(.title2.bold())
                    Text("⌥V — открыть историю буфера обмена").foregroundStyle(.secondary)
                }
            }

            Text("Чтобы выбранная запись сразу вставлялась туда, где стоит курсор, разрешите Buffer «Универсальный доступ». Без него Buffer будет только копировать.")
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: model.trusted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(model.trusted ? Color.green : Color.secondary)
                Text(model.trusted ? "Доступ выдан, всё готово" : "Включите Buffer в списке «Универсальный доступ»")
            }
            .font(.callout)

            HStack {
                if !model.trusted {
                    Button("Только копировать", action: copyOnly)
                }
                Spacer()
                if model.trusted {
                    Button("Готово", action: done).keyboardShortcut(.defaultAction)
                } else {
                    Button("Открыть настройки", action: openSettings).keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// First-run window: explains the Accessibility permission and watches until it is granted.
final class OnboardingController: NSObject, NSWindowDelegate {
    var onCopyOnly: () -> Void = {}

    private let model = OnboardingModel()
    private var window: NSWindow?
    private var timer: Timer?

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        model.trusted = Paster.isTrusted(prompt: false)
        if window == nil {
            let view = OnboardingView(
                model: model,
                openSettings: { [weak self] in self?.openSettings() },
                copyOnly: { [weak self] in
                    self?.onCopyOnly()
                    self?.close()
                },
                done: { [weak self] in self?.close() }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Buffer"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startPolling()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }

    /// Debug helper: writes the window contents to PNG.
    func snapshot(to url: URL) {
        guard let view = window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    private func openSettings() {
        // The prompting call adds Buffer to the Accessibility list, so the user only flips the switch.
        _ = Paster.isTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPolling() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let trusted = Paster.isTrusted(prompt: false)
        guard trusted != model.trusted else { return }
        model.trusted = trusted
        guard trusted else { return }
        Log.write("onboarding: accessibility granted")
        // Bring the window back from behind System Settings to show the checkmark, then close it.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.close() }
    }
}
