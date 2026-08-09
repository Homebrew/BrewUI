//
//  CommandJobRevisionTests.swift
//  BrewTests
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct CommandJobRevisionTests {
    @Test func `an incomplete line is replaced rather than appended`() {
        let job = makeJob()

        job.appendOutput(line("10%", isComplete: false))
        job.appendOutput(line("50%", isComplete: false))
        job.appendOutput(line("100%", isComplete: false))

        #expect(job.output.map(\.text) == ["100%"])
    }

    @Test func `a revision keeps the row's identity`() {
        // Identity stability is what makes the row animate in place instead of being torn down and
        // rebuilt by anything keyed on `id`.
        let job = makeJob()
        job.appendOutput(line("10%", isComplete: false))
        let originalID = job.output[0].id

        job.appendOutput(line("50%", isComplete: false))

        #expect(job.output[0].id == originalID)
    }

    @Test func `completing a line settles it so the next one appends`() {
        let job = makeJob()

        job.appendOutput(line("100%", isComplete: false))
        job.appendOutput(line("100%", isComplete: true))
        job.appendOutput(line("Downloaded", isComplete: true))

        #expect(job.output.map(\.text) == ["100%", "Downloaded"])
    }

    @Test func `complete lines always append`() {
        let job = makeJob()

        job.appendOutput(line("one", isComplete: true))
        job.appendOutput(line("two", isComplete: true))

        #expect(job.output.map(\.text) == ["one", "two"])
    }

    @Test func `a whole progress bar leaves a single row behind`() {
        // End to end for the reported bug: many revisions, one settled row.
        let job = makeJob()

        for percent in stride(from: 0, through: 100, by: 5) {
            job.appendOutput(line("#### \(percent)%", isComplete: false))
        }
        job.appendOutput(line("#### 100%", isComplete: true))

        #expect(job.output.map(\.text) == ["#### 100%"])
    }

    @Test func `the line cap still applies once revisions settle`() {
        let job = makeJob(maxOutputLines: 3)

        for index in 1 ... 5 {
            job.appendOutput(line("line \(index)", isComplete: true))
        }

        #expect(job.output.map(\.text) == ["line 3", "line 4", "line 5"])
    }
}

@MainActor
private func makeJob(maxOutputLines: Int = 50000) -> CommandJob {
    CommandJob(
        operationID: BrewOperationID(kind: .formula, name: "go"),
        command: "brew upgrade go",
        startedAt: Date(),
        phase: .running(.upgradeFormula),
        maxOutputLines: maxOutputLines,
    )
}

private func line(_ text: String, isComplete: Bool) -> BrewCommandOutputLine {
    BrewCommandOutputLine(stream: .stdout, text: text, isComplete: isComplete)
}
