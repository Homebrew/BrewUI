//
//  DoctorCopyTests.swift
//  BrewTests
//

@testable import BrewFeatureDoctor
import Testing

/// The reassurance is quoted from `brew doctor`, so drift away from brew's wording is a defect, not a
/// style choice. Compared against the CLI string with its hard line breaks unwrapped.
struct DoctorCopyTests {
    private static let brewPreamble = """
    Please note that these warnings are just used to help the Homebrew maintainers
    with debugging if you file an issue. If everything you use Homebrew for is
    working fine: please don't worry or file an issue; just ignore this. Thanks!
    """

    @Test func `warningPreamble matches brew doctor word for word`() {
        let unwrapped = Self.brewPreamble.replacingOccurrences(of: "\n", with: " ")
        #expect(DoctorCopy.warningPreamble == unwrapped)
    }

    @Test func `warningPreamble carries no hard line breaks so it can reflow`() {
        #expect(!DoctorCopy.warningPreamble.contains("\n"))
    }
}
