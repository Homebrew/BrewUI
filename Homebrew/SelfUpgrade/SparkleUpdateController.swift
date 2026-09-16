//
//  SparkleUpdateController.swift
//  Brew
//

import Foundation
import Observation
import Sparkle

/// The native updater used by releases installed outside Homebrew's cask flow.
///
/// The controller is deliberately inert until the release build supplies both a feed URL and a
/// public Ed25519 key. That keeps local development and test bundles from starting a misconfigured
/// Sparkle session while making the release-time security contract explicit.
@Observable
@MainActor
final class SparkleUpdateController {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?

    let isConfigured: Bool

    init(bundle: Bundle = .main) {
        guard Self.isConfigured(bundle: bundle) else {
            controller = nil
            isConfigured = false
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil,
        )
        isConfigured = true
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates == true
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    private static func isConfigured(bundle: Bundle) -> Bool {
        guard
            let infoDictionary = bundle.infoDictionary
        else {
            return false
        }
        return isConfigured(infoDictionary: infoDictionary)
    }

    static func isConfigured(infoDictionary: [String: Any]) -> Bool {
        guard
            let feedString = infoDictionary["SUFeedURL"] as? String,
            let feedURL = URL(string: feedString),
            feedURL.scheme == "https",
            feedURL.host != nil,
            let publicKey = infoDictionary["SUPublicEDKey"] as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }
        return true
    }
}
