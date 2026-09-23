//
//  DoctorCopy.swift
//  BrewFeatureDoctor
//

import Foundation

/// Localized reassurance; the original output remains available for diagnostics.
enum DoctorCopy {
    static let warningPreamble = String(localized: """
    Please note that these warnings are just used to help the Homebrew maintainers with debugging \
    if you file an issue. If everything you use Homebrew for is working fine: please don't worry \
    or file an issue; just ignore this. Thanks!
    """, bundle: #bundle, comment: "Doctor reassurance before the warnings; raw console output remains verbatim")
}
