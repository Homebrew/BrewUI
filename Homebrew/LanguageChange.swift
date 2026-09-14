import AppKit
import BrewCLI
import BrewCore
import BrewUIComponents

@MainActor
final class LanguageChange {
    private let preferences: LanguagePreferences
    private let commandCenter: SerialBrewCommandCenter
    private let relaunch: () async throws -> Void
    private var isPresenting = false
    private var offeredInitialChange = false

    init(preferences: LanguagePreferences, commandCenter: SerialBrewCommandCenter, relaunch: @escaping () async throws -> Void) {
        self.preferences = preferences
        self.commandCenter = commandCenter
        self.relaunch = relaunch
    }

    func offerInitialChangeOnce() {
        guard !offeredInitialChange else { return }
        offeredInitialChange = true
        requestRelaunch()
    }

    func select(_ language: String?) {
        preferences.select(language)
        requestRelaunch()
    }

    func requestRelaunch() {
        guard preferences.hasPendingChange, !isPresenting else { return }
        isPresenting = true
        let window = NSApp.keyWindow ?? NSApp.mainWindow
        Task {
            defer { isPresenting = false }
            let phases = await commandCenter.runningPhases()
            let isBusy = phases.values.contains { phase in
                if case .running = phase { return true }
                return false
            }
            let response = LanguageChangePrompt.present(
                localization: preferences.localization,
                language: preferences.resolvedPendingLanguage,
                isBusy: isBusy,
                centeredOn: window,
            )
            switch response {
            case .alertSecondButtonReturn:
                await reopen()
            case .alertThirdButtonReturn:
                preferences.select(preferences.activeSelection)
            default:
                break
            }
        }
    }

    private func reopen() async {
        // Check and lock on the same actor as command submission so an install cannot start after the idle check.
        guard await commandCenter.beginRelaunch() else {
            showError(preferences.localization.string("A Homebrew operation is running. You can reopen the app after it finishes; it will not reopen automatically."))
            return
        }
        do {
            try await relaunch()
        } catch {
            await commandCenter.cancelRelaunch()
            showError(error.localizedDescription)
        }
    }

    private func showError(_ detail: String) {
        let alert = NSAlert()
        alert.messageText = preferences.localization.string("Could Not Reopen Homebrew")
        alert.informativeText = detail
        alert.addButton(withTitle: preferences.localization.string("OK"))
        run(alert, centeredOn: NSApp.keyWindow ?? NSApp.mainWindow)
    }

    @discardableResult
    private func run(_ alert: NSAlert, centeredOn owner: NSWindow?) -> NSApplication.ModalResponse {
        // Keep a free-standing alert; center it on the current app window after layout, rather than attaching it as a sheet.
        alert.layout()
        if let owner {
            let size = alert.window.frame.size
            alert.window.setFrameOrigin(NSPoint(x: owner.frame.midX - size.width / 2, y: owner.frame.midY - size.height / 2))
        }
        return alert.runModal()
    }
}
