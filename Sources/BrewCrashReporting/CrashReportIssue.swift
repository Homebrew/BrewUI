//
//  CrashReportIssue.swift
//  Brew
//

import Foundation

/// Builds a pre-filled "new issue" URL on the app's GitHub repository from a
/// crash report, so a user can file it with one click.
public enum CrashReportIssue {
    /// The app's GitHub repository.
    public static let repositoryURL = URL(string: "https://github.com/Homebrew/BrewUI")!

    /// GitHub rejects issue URLs whose body is too long. Keep the encoded body
    /// well under GitHub's ~8k URL ceiling; anything longer is truncated with a
    /// note asking the user to attach the full log.
    static let maxBodyLength = 6000

    /// A pre-filled new-issue URL. The user still reviews and submits it on
    /// GitHub — nothing is sent automatically.
    public static func url(for report: CrashReport) -> URL {
        var components = URLComponents(
            url: repositoryURL.appendingPathComponent("issues/new"),
            resolvingAgainstBaseURL: false,
        )!
        components.queryItems = [
            URLQueryItem(name: "title", value: "Crash: \(report.summary)"),
            URLQueryItem(name: "body", value: body(for: report)),
        ]
        // `URLComponents` leaves some sub-delimiters unescaped; GitHub is happy
        // with the default encoding, so `components.url` is sufficient.
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

    private static func truncatedLog(_ text: String) -> String {
        guard text.count > maxBodyLength else {
            return text
        }
        let prefix = text.prefix(maxBodyLength)
        return prefix + "\n… (truncated — please attach the full crash log from " +
            "~/Library/Application Support/Brew/CrashReports)"
    }
}
