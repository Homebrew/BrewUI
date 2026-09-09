//
//  LocalizedStringResource+Module.swift
//  BrewFeatureDoctor
//

import Foundation

extension LocalizedStringResource {
    /// Builds a resource bound to this module's catalogue. See the equivalent in `BrewUIComponents`
    /// for why the default `Bundle.main` is wrong here and fails silently.
    init(doctor key: String.LocalizationValue) {
        self.init(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

public extension Bundle {
    /// `Bundle.module` is internal to its own module. The Xcode test target needs the same bundle to
    /// assert that a translation resolves, so it is exposed here — the only reason this is public.
    static var brewFeatureDoctor: Bundle {
        .module
    }
}
