@testable import BrewCore
import Foundation
import Testing

struct OperationFailureTests {
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

    @Test func `init catching localized error keeps its description and a diagnostic`() {
        let failure = OperationFailure(catching: LocalizedOperationFailure())

        guard case let .other(description, diagnostic) = failure else {
            Issue.record("expected other failure")
            return
        }
        #expect(description == "friendly failure")
        #expect(diagnostic?.isEmpty == false)
    }
}

private struct LocalizedOperationFailure: LocalizedError {
    var errorDescription: String? {
        "friendly failure"
    }
}
