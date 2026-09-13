import Foundation
import AppKit
import Sparkle

// MARK: - Sparkle User Driver Delegate
// Controls which buttons are shown in the update dialog.
// Setting allowsAutomaticUpdates to false disables the "Skip This Version" button.
private class MinaUpdaterDelegate: NSObject, SPUStandardUserDriverDelegate {

    /// Hide "Skip This Version" — every update must be acknowledged or deferred, never skipped forever.
    var supportsGentleScheduledUpdateReminders: Bool { return true }

    /// Called by Sparkle to decide if it can skip. We always return false → no skip button shown.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        return false // let Sparkle show the standard window, but with skip hidden
    }
}

public class UpdaterService: NSObject, ObservableObject {
    public static let shared = UpdaterService()

    private var updaterController: SPUStandardUpdaterController?
    private let delegate = MinaUpdaterDelegate()

    override private init() {
        super.init()
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: delegate
        )
        // Check every 4 hours instead of the default 24h
        updaterController?.updater.updateCheckInterval = 4 * 60 * 60
        // Automatically download updates in background (user still confirms install)
        updaterController?.updater.automaticallyDownloadsUpdates = true
    }

    public func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    public var canCheckForUpdates: Bool {
        return updaterController?.updater.canCheckForUpdates ?? true
    }
}
