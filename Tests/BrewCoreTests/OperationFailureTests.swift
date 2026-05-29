@testable import BrewCore
import BrewCoreTestSupport
import Foundation
import Testing

struct OperationFailureTests {
    @Test func `userFacingMessage trims stderr for brew command failures`() {
        let failure = OperationFailure.brewCommand(exitCode: 1, stderr: "  blocked by dependency \n")

        #expect(failure.userFacingMessage == "blocked by dependency")
    }

    @Test func `userFacingMessage falls back when brew command stderr is empty`() {
        let failure = OperationFailure.brewCommand(exitCode: 1, stderr: "   ")
        let expected = String(
            localized: "Homebrew command failed.",
            comment: "Shown when brew exits non-zero with no stderr",
        )

        #expect(failure.userFacingMessage == expected)
    }

    @Test func `userFacingMessage uses missing brew copy for missing executable failures`() {
        let expected = String(
            localized: "Could not find the brew executable.",
            comment: "Shown when brew binary is missing",
        )

        #expect(OperationFailure.brewExecutableNotFound.userFacingMessage == expected)
    }

    @Test func `init catching brew failed preserves exit code and stderr`() {
        let failure = OperationFailure(catching: BrewCommandError.failed(exitCode: 7, stderr: "boom"))

        #expect(failure == .brewCommand(exitCode: 7, stderr: "boom"))
    }

    @Test func `init catching launch failure maps to launch failure case`() {
        let failure = OperationFailure(catching: BrewCommandError.launchFailed(underlying: "spawn failed"))

        #expect(failure == .brewLaunchFailed(diagnostic: "spawn failed"))
    }

    @Test func `init catching missing brew maps to brew executable not found`() {
        let failure = OperationFailure(catching: BrewLookupError.executableNotFound)

        #expect(failure == .brewExecutableNotFound)
    }

    @Test func `init catching localized error maps to generic with user facing description`() {
        let failure = OperationFailure(catching: LocalizedOperationFailure())

        guard case let .generic(userFacing, diagnostic) = failure else {
            Issue.record("expected generic failure")
            return
        }
        #expect(userFacing == "friendly failure")
        #expect(diagnostic?.isEmpty == false)
    }
}

private struct LocalizedOperationFailure: LocalizedError {
    var errorDescription: String? {
        "friendly failure"
    }
}
