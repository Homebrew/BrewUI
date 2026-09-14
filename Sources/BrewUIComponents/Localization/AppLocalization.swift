import Foundation
import SwiftUI

public struct AppLocalization {
    public let locale: Locale
    private let bundle: Bundle

    public init(language: String? = nil, bundle: Bundle = .main) {
        let language = language ?? bundle.preferredLocalizations.first ?? "en"
        locale = Locale(identifier: language)
        // Pick the resource directory explicitly; passing a locale alone does not change Foundation's bundle language lookup.
        let path = bundle.path(forResource: language, ofType: "lproj")
            ?? bundle.path(forResource: "en", ofType: "lproj")
        self.bundle = path.flatMap(Bundle.init(path:)) ?? bundle
    }

    public var layoutDirection: LayoutDirection {
        locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    public func string(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle, locale: locale)
    }
}

public extension EnvironmentValues {
    @Entry var brewLocalization = AppLocalization()
}
