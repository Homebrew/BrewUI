//
//  LocalizedStringResource+Module.swift
//  BrewUIComponents
//

import Foundation

extension LocalizedStringResource {
    /// Builds a resource bound to this module's catalogue.
    ///
    /// `LocalizedStringResource` defaults to `Bundle.main`, which in a SwiftPM module is the app —
    /// not where `Localizable.xcstrings` was processed to. Resolution against the wrong bundle does
    /// not throw; it returns the key, so the string silently stays English. Every user-facing string
    /// in `BrewUIComponents` goes through here.
    init(uiComponents key: String.LocalizationValue) {
        self.init(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

public extension Bundle {
    /// `Bundle.module` is internal to its own module. The Xcode test target needs the same bundle
    /// to assert that a translation resolves, so it is exposed here — the only reason this is public.
    static var brewUIComponents: Bundle {
        .module
    }
}
