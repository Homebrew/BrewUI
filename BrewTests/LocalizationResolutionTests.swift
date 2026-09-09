//
//  LocalizationResolutionTests.swift
//  BrewTests
//

import BrewUIComponents
import Foundation
import Testing

/// Asserts a translation actually comes back, which only `xcodebuild` can demonstrate: the SwiftPM
/// CLI copies `Localizable.xcstrings` into the module bundle raw, while `xcodebuild` compiles it to
/// `<lang>.lproj/Localizable.strings`. That is why this suite lives in the Xcode target — CI runs it
/// via test plan `Brew-Unit` — and not beside the rest of `BrewUIComponents`' tests under `Tests/`.
struct LocalizationResolutionTests {
    private static func localized(_ resource: LocalizedStringResource, in identifier: String) -> String {
        var resolved = resource
        resolved.locale = Locale(identifier: identifier)
        return String(localized: resolved)
    }

    @Test func `a module string resolves in both languages`() {
        let retry = LocalizedStringResource("Retry", bundle: .atURL(Bundle.brewUIComponents.bundleURL))
        #expect(
            [Self.localized(retry, in: "en"), Self.localized(retry, in: "pt-BR")]
                == ["Retry", "Tentar novamente"],
        )
    }

    /// One representative count per unit. This is where plural variations are actually exercised:
    /// the count comes from a `%lld` argument, and the catalogue picks `one` or `other` per language.
    ///
    /// `@MainActor`: `BrewUIComponents` defaults every declaration to main-actor isolation
    /// (`Package.swift`'s `.defaultIsolation(MainActor.self)`), so `RelativeTimeText.resource` is
    /// main-actor-isolated too. `BrewTests` carries no such default, so the call needs an isolated
    /// caller — unlike `Tests/BrewUIComponentsTests`, whose own target shares that same default.
    @MainActor
    @Test func `relative time resolves in English`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let phrases = [0, 60, 5 * 60, 3600, 24 * 3600].map { secondsAgo in
            Self.localized(
                RelativeTimeText.resource(
                    for: now.addingTimeInterval(-TimeInterval(secondsAgo)),
                    relativeTo: now,
                ),
                in: "en",
            )
        }
        #expect(phrases == ["just now", "1 minute ago", "5 minutes ago", "1 hour ago", "1 day ago"])
    }

    /// Portuguese takes the singular below two, as English does here — but through catalogue plural
    /// variations rather than a hand-written ternary, so a language with different rules stays right.
    @MainActor
    @Test func `relative time resolves in Portuguese`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let phrases = [0, 60, 5 * 60, 3600, 24 * 3600].map { secondsAgo in
            Self.localized(
                RelativeTimeText.resource(
                    for: now.addingTimeInterval(-TimeInterval(secondsAgo)),
                    relativeTo: now,
                ),
                in: "pt-BR",
            )
        }
        #expect(phrases == ["agora mesmo", "há 1 minuto", "há 5 minutos", "há 1 hora", "há 1 dia"])
    }
}
