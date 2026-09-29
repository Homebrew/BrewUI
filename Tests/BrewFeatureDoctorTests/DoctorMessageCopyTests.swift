//
//  DoctorMessageCopyTests.swift
//  BrewTests
//

@testable import BrewFeatureDoctor
import BrewRepositories
import Testing

struct DoctorMessageCopyTests {
    @Test func `known finding titles are presentation copy`() {
        #expect(DoctorMessageCopy.title("Some installed formulae are deprecated or disabled.") ==
            "Some installed formulae are deprecated or disabled.")
        #expect(DoctorMessageCopy.title("The following taps are not trusted:") ==
            "The following taps are not trusted:")
    }

    @Test func `unknown upstream findings remain verbatim`() {
        let unknown = "Homebrew changed this warning in a future release."
        #expect(DoctorMessageCopy.title(unknown) == unknown)
        #expect(DoctorMessageCopy.prose([unknown]) == unknown)
        #expect(DoctorMessageCopy.caption(unknown) == unknown)
    }

    @Test func `path values remain unchanged in known titles`() {
        let title = "Unbrewed header files were found in /usr/local/include."
        #expect(DoctorMessageCopy.title(title) == title)
        let other = "Unbrewed header files were found in /some/other/include."
        #expect(DoctorMessageCopy.title(other) == other)
    }

    @Test func `commands and data are outside the localisation boundary`() {
        let paragraph = [
            "Homebrew is currently ignoring formulae, casks and commands",
            "from these taps because tap trust is required.",
        ]
        #expect(DoctorMessageCopy.prose(paragraph) == paragraph.joined(separator: " "))
        #expect(DoctorMessageCopy.caption("Trust installed formulae from these taps with:") ==
            "Trust installed formulae from these taps with:")
    }

    @Test func `adjacent known prose is localised without consuming unknown text`() {
        let lines = [
            "Homebrew is currently ignoring formulae, casks and commands",
            "from these taps because tap trust is required.",
            "Prefer trusting only the specific formulae, casks or commands you need.",
            "Trust installed formulae from these taps with:",
            "A future Homebrew explanation stays verbatim.",
        ]

        #expect(DoctorMessageCopy.prose(lines) == """
        Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.
        Prefer trusting only the specific formulae, casks or commands you need.
        Trust installed formulae from these taps with:
        A future Homebrew explanation stays verbatim.
        """)
    }

    @Test func `presentation copy does not change parsed evidence`() throws {
        let output = """
        Warning: Some installed formulae are deprecated or disabled.
        You should find replacements for the following formulae:
          dotnet@6
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let item = DoctorIssueItem(issue: issue)

        _ = DoctorMessageCopy.title(item.title)
        _ = DoctorMessageCopy.caption("You should find replacements for the following formulae:")

        #expect(item.rawText == output)
    }

    @Test func `tap trust commands keep their CLI arguments`() throws {
        let output = """
        Warning: The following taps are not trusted:
          oven-sh/bun
        Trust installed formulae from these taps with:
          brew trust --formula oven-sh/bun/bun
        Trust other specific casks and commands with:
          brew trust --cask <user>/<tap>/<cask>
          brew trust --command <user>/<tap>/<command>
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let item = DoctorIssueItem(issue: issue)
        let commands = item.blocks.flatMap { block -> [String] in
            switch block.content {
            case let .command(steps):
                steps.map(\.displayCommand)
            case let .data(items):
                items.filter { $0.hasPrefix("brew trust ") }
            case .prose, .link:
                []
            }
        }

        #expect(commands == [
            "brew trust --formula oven-sh/bun/bun",
            "brew trust --cask <user>/<tap>/<cask>",
            "brew trust --command <user>/<tap>/<command>",
        ])
    }
}
