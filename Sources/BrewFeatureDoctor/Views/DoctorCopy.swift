//
//  DoctorCopy.swift
//  BrewFeatureDoctor
//

/// Doctor copy that must match `brew doctor` word for word.
enum DoctorCopy {
    static let warningPreamble = """
    Please note that these warnings are just used to help the Homebrew maintainers with debugging \
    if you file an issue. If everything you use Homebrew for is working fine: please don't worry \
    or file an issue; just ignore this. Thanks!
    """
}
