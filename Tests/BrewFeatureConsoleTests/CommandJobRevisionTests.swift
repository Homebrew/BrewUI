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

    // MARK: - Multi-row revisions

    @Test func `a row offset revises that many rows back from the end`() {
        let job = makeJob()
        for text in ["alpha", "beta", "gamma"] {
            job.appendOutput(line(text, isComplete: true))
        }

        job.appendOutput(line("ALPHA", isComplete: true, rowOffset: 2))

        #expect(job.output.map(\.text) == ["ALPHA", "beta", "gamma"])
    }

    @Test func `a revised row keeps its identity so the list animates it`() {
        let job = makeJob()
        for text in ["alpha", "beta", "gamma"] {
            job.appendOutput(line(text, isComplete: true))
        }
        let originalID = job.output[0].id

        job.appendOutput(line("ALPHA", isComplete: true, rowOffset: 2))

        #expect(job.output[0].id == originalID)
    }

    @Test func `a whole redrawn block leaves one row per entry`() {
        let job = makeJob()
        for text in ["alpha 1MB", "beta 1MB"] {
            job.appendOutput(line(text, isComplete: true))
        }
        job.appendOutput(line("gamma 1MB", isComplete: false))

        for tick in 2 ... 20 {
            job.appendOutput(line("alpha \(tick)MB", isComplete: true, rowOffset: 2))
            job.appendOutput(line("beta \(tick)MB", isComplete: true, rowOffset: 1))
            job.appendOutput(line("gamma \(tick)MB", isComplete: false, rowOffset: 0))
        }

        #expect(job.output.map(\.text) == ["alpha 20MB", "beta 20MB", "gamma 20MB"])
    }

    @Test func `an offset past the start of the buffer is dropped`() {
        let job = makeJob()
        job.appendOutput(line("only", isComplete: true))

        job.appendOutput(line("nowhere", isComplete: true, rowOffset: 5))

        #expect(job.output.map(\.text) == ["only"])
    }

    @Test func `offsets stay correct after the line cap trims the front`() {
        let job = makeJob(maxOutputLines: 3)
        for index in 1 ... 5 {
            job.appendOutput(line("line \(index)", isComplete: true))
        }

        job.appendOutput(line("REVISED", isComplete: true, rowOffset: 1))

        #expect(job.output.map(\.text) == ["line 3", "REVISED", "line 5"])
    }

    @Test func `a revision at offset zero still replaces the trailing row`() {
        let job = makeJob()
        job.appendOutput(line("10%", isComplete: false))

        job.appendOutput(line("90%", isComplete: false, rowOffset: 0))

        #expect(job.output.map(\.text) == ["90%"])
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

private func line(_ text: String, isComplete: Bool, rowOffset: Int = 0) -> BrewCommandOutputLine {
    BrewCommandOutputLine(stream: .stdout, text: text, isComplete: isComplete, rowOffset: rowOffset)
}
