import SwiftUI
import AppKit

private class DashboardWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command {
            switch event.charactersIgnoringModifiers {
            case "w":
                self.close()
                return true
            case "q":
                NSApp.terminate(nil)
                return true
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                    return true
                }
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                    return true
                }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                    return true
                }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                    return true
                }
            case "z":
                let sel = flags.contains(.shift) ? Selector(("redo:")) : Selector(("undo:"))
                if NSApp.sendAction(sel, to: nil, from: self) {
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

public class DashboardWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = DashboardWindowController()
    private var eventMonitor: Any?

    private init() {
        let window = DashboardWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 960, height: 680)
        window.title = "MinaFlow Dashboard"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        let isDark = ConfigManager.shared.config.appTheme == "dark"
        window.backgroundColor = isDark ? NSColor(red: 9/255.0, green: 9/255.0, blue: 11/255.0, alpha: 1.0) : NSColor.white
        window.center()
        window.setFrameAutosaveName("MinaFlowDashboardWindow")
        window.contentView = NSHostingView(rootView: DashboardView(initialTab: 0))
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        setupKeyMonitor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func windowWillClose(_ notification: Notification) {
        let showDock = ConfigManager.shared.config.showDockIcon
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }

    public func applyTheme(isDark: Bool) {
        guard let window = window else { return }
        window.backgroundColor = isDark ? NSColor(red: 9/255.0, green: 9/255.0, blue: 11/255.0, alpha: 1.0) : NSColor.white
    }

    private func setupKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let win = self.window, win.isVisible else {
                return event
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command {
                if event.charactersIgnoringModifiers == "w" {
                    win.close()
                    return nil
                } else if event.charactersIgnoringModifiers == "q" {
                    NSApp.terminate(nil)
                    return nil
                }
            }
            return event
        }
    }

    public func show(tab: Int = 0, subTab: Int? = nil) {
        guard let window = window else { return }
        NSApp.setActivationPolicy(.regular)
        let isDark = ConfigManager.shared.config.appTheme == "dark"
        applyTheme(isDark: isDark)
        window.contentView = NSHostingView(rootView: DashboardView(initialTab: tab, initialSubTab: subTab))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let sub = subTab {
            NotificationCenter.default.post(name: Notification.Name("MinaFlowSwitchSpeechSubTab"), object: sub)
        }

        // Validate license key whenever dashboard is opened
        DodoPaymentsService.shared.recheckLicenseInBackground()
    }
}

public typealias SettingsWindowController = DashboardWindowController

