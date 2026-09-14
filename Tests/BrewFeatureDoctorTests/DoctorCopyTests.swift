//
//  DoctorCopyTests.swift
//  BrewTests
//

@testable import BrewFeatureDoctor
import Testing

/// Drift away from brew's English source wording is a defect, not a style choice.
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

    @Test func `known doctor prose is localized while unknown output is preserved`() {
        #expect(DoctorCopy.localized("A newer Command Line Tools release is available.") == "A newer Command Line Tools release is available.")
        #expect(DoctorCopy.localized("You should download the Command Line Tools for Xcode 26.6.") == "You should download the Command Line Tools for Xcode 26.6.")
        #expect(DoctorCopy.localized("Untap them with:") == "Untap them with:")
        #expect(DoctorCopy.localized("For more information, see:") == "For more information, see:")
        let reportMessage = "Please report this issue to the user/tap (not Homebrew/* repositories), " +
            "or even better, submit a PR to fix it:"
        #expect(DoctorCopy.localized(reportMessage) == reportMessage)
        #expect(DoctorCopy.localized("A future brew warning") == "A future brew warning")
    }
}
