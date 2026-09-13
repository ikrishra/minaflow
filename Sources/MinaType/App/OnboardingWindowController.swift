import SwiftUI
import AppKit

private class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

public class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = OnboardingWindowController()

    private init() {
        let win = OnboardingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Welcome to MinaFlow"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false

        let isDark = ConfigManager.shared.config.appTheme == "dark"
        win.backgroundColor = isDark
            ? NSColor(red: 9/255.0, green: 9/255.0, blue: 11/255.0, alpha: 1)
            : NSColor.white

        win.contentView = NSHostingView(rootView: OnboardingView())
        win.center()

        super.init(window: win)
        win.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - NSWindowDelegate

    /// Intercept the ✕ close button.
    /// If onboarding is not done, show a macOS-style alert so the user
    /// can choose to quit the app rather than being silently stuck.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        let done = UserDefaults.standard.bool(forKey: "MinaFlow_HasCompletedOnboarding")
        if done { return true }

        let alert = NSAlert()
        alert.messageText = "Quit MinaFlow Setup?"
        alert.informativeText = "MinaFlow needs to finish setup before it can run. You can quit now and resume setup next time you launch the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit MinaFlow")
        alert.addButton(withTitle: "Continue Setup")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
        // "Continue Setup" — keep the window open
        return false
    }

    // MARK: - Public API

    public func show() {
        guard let window = window else { return }
        NSApp.setActivationPolicy(.regular)
        let isDark = ConfigManager.shared.config.appTheme == "dark"
        window.backgroundColor = isDark
            ? NSColor(red: 9/255.0, green: 9/255.0, blue: 11/255.0, alpha: 1)
            : NSColor.white
        // Refresh content so @State re-initializes from current ConfigManager values
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Called by OnboardingView.finish() after the user completes all steps.
    public override func close() {
        window?.orderOut(nil)
        let showDock = ConfigManager.shared.config.showDockIcon
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }
}
