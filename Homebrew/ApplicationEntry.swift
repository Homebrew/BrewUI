import AppKit
import BrewUIComponents
import BrewUITestContract
import Foundation
import SwiftUI

@main
enum ApplicationEntry {
    private static let relaunchFlag = "--reopen-after-process"

    @MainActor
    static func main() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.count >= 3, arguments[1] == relaunchFlag {
            guard let parent = Int32(arguments[2]), parent > 1 else { return }
            await reopenAfterExit(parent: parent, arguments: Array(arguments.dropFirst(3)))
            return
        }
        prepareLanguage()
        BrewApp.main()
    }

    static func languageDefaults(for domain: String) -> UserDefaults? {
        // The current app domain must use `.standard`; `suiteName` cannot be the app's own bundle identifier.
        domain == Bundle.main.bundleIdentifier ? .standard : UserDefaults(suiteName: domain)
    }

    @MainActor
    private static func prepareLanguage() {
        let environment = ProcessInfo.processInfo.environment
        let testing = BrewUITestingLaunchConfiguration.current() != nil
        let domain = testing ? environment[BrewUITestingEnvironmentKey.languagePreferencesDomain] : Bundle.main.bundleIdentifier
        guard let domain, let defaults = languageDefaults(for: domain) else { return }
        _ = LanguagePreferences.prepareForLaunch(
            defaults: defaults, domain: domain, localizations: Bundle.main.localizations,
            applyNativeOverride: { languages in
                guard testing else { return }
                var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
                arguments["AppleLanguages"] = languages ?? ["en"]
                UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            },
        )
    }

    @MainActor
    static func relaunch(arguments: [String], environment: [String: String]) async throws {
        guard let executable = Bundle.main.executableURL else { throw CocoaError(.fileNoSuchFile) }
        let helper = Process()
        helper.executableURL = executable
        helper.arguments = [relaunchFlag, String(ProcessInfo.processInfo.processIdentifier)] + arguments
        helper.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        helper.environment?.removeValue(forKey: BrewUITestingEnvironmentKey.fixturesRoot)
        // `terminate` can return before the process exits; only fail and release the lock if the helper quits while this process is still running.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            helper.terminationHandler = { _ in continuation.resume(throwing: CocoaError(.userCancelled)) }
            do {
                try helper.run()
                NSApplication.shared.terminate(nil)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @MainActor
    private static func reopenAfterExit(parent: Int32, arguments: [String]) async {
        let deadline = ContinuousClock.now + .seconds(30)
        while kill(parent, 0) == 0 || errno != ESRCH {
            guard ContinuousClock.now < deadline else { return }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        let source = ProcessInfo.processInfo.environment
        configuration.environment = Dictionary(uniqueKeysWithValues: [
            BrewUITestingEnvironmentKey.scenario,
            BrewUITestingEnvironmentKey.payload,
            BrewUITestingEnvironmentKey.languagePreferencesDomain,
        ].compactMap { key in source[key].map { (key, $0) } })
        configuration.createsNewApplicationInstance = true
        // Background tests must not steal the foreground; a user-initiated reopen should show the new window.
        configuration.activates = BrewUITestingLaunchConfiguration.current() == nil
        do {
            _ = try await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        } catch {
            // The old process has already exited, so the helper must surface the failure instead of only logging a user-initiated error.
            let alert = NSAlert()
            alert.messageText = String(localized: "Could Not Reopen Homebrew")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: String(localized: "OK"))
            alert.runModal()
        }
    }
}
