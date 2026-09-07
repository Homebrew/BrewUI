//
//  CrashReportIssue.swift
//  Brew
//

import BrewAppStorage
import Foundation

/// Builds a pre-filled "new issue" URL on the app's GitHub repository from a
/// crash report, so a user can file it with one click.
enum CrashReportIssue {
    static let repositoryURL = URL(string: "https://github.com/Homebrew/BrewUI")!

    /// Kept under GitHub's ~8k URL ceiling; longer logs are truncated.
    static let maxBodyLength = 6000

    /// A pre-filled new-issue URL. Nothing is sent until the user submits it on GitHub.
    static func url(for report: CrashReport) -> URL {
        var components = URLComponents(
            url: repositoryURL.appendingPathComponent("issues/new"),
            resolvingAgainstBaseURL: false,
        )!
        components.queryItems = [
            URLQueryItem(name: "title", value: "Crash: \(report.summary)"),
            URLQueryItem(name: "body", value: body(for: report)),
        ]
        return components.url ?? repositoryURL
    }

    private static func body(for report: CrashReport) -> String {
        let log = truncatedLog(report.text)
        return """
        <!-- Thanks for helping improve the Homebrew app. -->
        The app crashed on a previous launch. Please describe what you were \
        doing when it happened:



        <details>
        <summary>Automatic crash report</summary>

        ```
        \(log)
        ```
        </details>
        """
    }

    /// The tilde form of ``CrashReportStore/defaultDirectoryURL``, which is what a person needs in
    /// order to find the file in Finder.
    private static let reportDirectoryDisplayPath =
        "~/Library/Application Support/\(BrewAppStorageLocations.bundleIdentifier)/" +
        CrashReportStore.directoryName

    private static func truncatedLog(_ text: String) -> String {
        guard text.count > maxBodyLength else {
            return text
        }
        let prefix = text.prefix(maxBodyLength)
        return prefix + "\n… (truncated — please attach the full crash log from " +
            "\(reportDirectoryDisplayPath))"
    }
}
