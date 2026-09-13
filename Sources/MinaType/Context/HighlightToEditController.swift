import Foundation
import AppKit
import Carbon

public final class HighlightToEditController: ObservableObject {
    public static let shared = HighlightToEditController()

    @Published public var isEditingSelection: Bool = false
    @Published public var selectedText: String? = nil

    private init() {}

    /// Captures the currently selected text in the active frontmost application
    public func captureSelectedText() -> String? {
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount

        // Simulate Cmd+C to copy selected text
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Give macOS a moment to update the pasteboard
        usleep(75_000) // 75ms

        if pasteboard.changeCount != originalChangeCount {
            if let copied = pasteboard.string(forType: .string), !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return copied
            }
        }

        return nil
    }

    public func buildEditPrompt(originalText: String, instruction: String) -> String {
        return """
        You are a surgical AI text editor.
        The user highlighted this text:
        \"\"\"
        \(originalText)
        \"\"\"

        The user spoke this voice edit instruction:
        "\(instruction)"

        Apply the instruction to the highlighted text. Output ONLY the rewritten replacement text.
        Do NOT wrap in quotes. Do NOT provide explanations, pleasantries, or chat commentary.
        """
    }
}
