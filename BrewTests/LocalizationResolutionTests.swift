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
}
