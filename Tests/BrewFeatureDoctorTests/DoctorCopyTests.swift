//
//  DoctorCopyTests.swift
//  BrewTests
//

@testable import BrewFeatureDoctor
import Testing

/// Drift away from brew's own wording is a defect, not a style choice.
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
