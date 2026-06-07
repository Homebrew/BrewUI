@testable import BrewFeatureConfig
import Testing

struct CaskOptsTests {
    @Test func `empty input is fully clean`() {
        let advisory = CaskOpts.advisory(for: "")
        #expect(advisory.isClean)
        #expect(advisory.unrecognisedFlags.isEmpty)
        #expect(!advisory.hasNoQuarantine)
        #expect(!advisory.hasForce)
    }

    @Test func `recognised flags without dangerous ones are clean`() {
        let advisory = CaskOpts.advisory(for: "--appdir=/Applications --require-sha")
        #expect(advisory.isClean)
    }

    @Test func `bare values are ignored (not flagged as unrecognised)`() {
        // `--appdir /Applications` is the space-separated form; the value should not be classified.
        let advisory = CaskOpts.advisory(for: "--appdir /Applications")
        #expect(advisory.isClean)
    }

    @Test func `unrecognised flags are surfaced for review`() {
        let advisory = CaskOpts.advisory(for: "--appdir=/Applications --made-up-flag")
        #expect(advisory.unrecognisedFlags == ["--made-up-flag"])
    }

    @Test func `--no-quarantine is flagged as dangerous`() {
        let advisory = CaskOpts.advisory(for: "--no-quarantine")
        #expect(advisory.hasNoQuarantine)
        #expect(!advisory.isClean)
    }

    @Test func `--force is flagged as dangerous`() {
        let advisory = CaskOpts.advisory(for: "--force")
        #expect(advisory.hasForce)
        #expect(!advisory.isClean)
    }

    @Test func `multiple dangerous flags compound`() {
        let advisory = CaskOpts.advisory(for: "--no-quarantine --force --appdir=/A")
        #expect(advisory.hasNoQuarantine)
        #expect(advisory.hasForce)
        #expect(advisory.unrecognisedFlags.isEmpty)
    }

    @Test func `unrecognised flags are deduplicated`() {
        let advisory = CaskOpts.advisory(for: "--foo --foo --bar")
        #expect(advisory.unrecognisedFlags == ["--foo", "--bar"])
    }

    @Test func `--flag=value form is classified by flag name`() {
        let advisory = CaskOpts.advisory(for: "--no-quarantine=ignored")
        #expect(advisory.hasNoQuarantine)
    }
}
