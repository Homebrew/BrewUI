//
//  CommandFailureDetailTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

/// A terminal merges the streams, so `standardError` is empty; reading only stderr reduced every failed
/// install to a bare exit code.
struct CommandFailureDetailTests {
    @Test func `stderr is preferred when the run kept the streams apart`() {
        let output = makeOutput(standardOutput: "progress noise", standardError: "Error: pipe failure")

        #expect(CommandFailureDetail.detail(from: output) == "Error: pipe failure")
    }

    @Test func `the transcript is used when stderr is empty`() {
        let output = makeOutput(standardOutput: "==> Downloading\nError: no such cask\n", standardError: "")

        #expect(CommandFailureDetail.detail(from: output) == "==> Downloading\nError: no such cask")
    }

    @Test func `whitespace-only stderr counts as empty`() {
        let output = makeOutput(standardOutput: "Error: the real one", standardError: "\n  \n")

        #expect(CommandFailureDetail.detail(from: output) == "Error: the real one")
    }

    @Test func `an empty run yields empty detail rather than a crash`() {
        #expect(CommandFailureDetail.detail(from: makeOutput(standardOutput: "", standardError: "")).isEmpty)
    }

    @Test func `only the tail of a long transcript is carried`() {
        let transcript = (1 ... 500).map { "line \($0)" }.joined(separator: "\n")

        let detail = CommandFailureDetail.detail(from: makeOutput(standardOutput: transcript, standardError: ""))

        #expect(detail.split(separator: "\n").count == CommandFailureDetail.maxTranscriptLines)
        #expect(detail.hasSuffix("line 500"))
    }

    @Test func `a trailing newline does not cost a line of the tail`() {
        let transcript = (1 ... 5).map { "line \($0)" }.joined(separator: "\n") + "\n"

        #expect(CommandFailureDetail.tail(of: transcript, lines: 2) == "line 4\nline 5")
    }

    @Test func `a transcript shorter than the limit is carried whole`() {
        #expect(CommandFailureDetail.tail(of: "one\ntwo", lines: 20) == "one\ntwo")
    }
}

private func makeOutput(standardOutput: String, standardError: String) -> CommandOutput {
    CommandOutput(standardOutput: standardOutput, standardError: standardError, terminationStatus: 1)
}
