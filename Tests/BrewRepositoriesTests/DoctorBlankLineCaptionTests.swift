//
//  DoctorBlankLineCaptionTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewRepositories
import Foundation
import Testing

struct DoctorBlankLineCaptionTests {
    @Test func `blank line between a remediation caption and its data keeps the caption`() throws {
        let output = """
        Warning: Some installed formulae are deprecated or disabled.
        You should find replacements for the following formulae:

          dotnet@6
          icu4c@77
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let block = try #require(issue.blocks.first)

        #expect(block.caption == "You should find replacements for the following formulae:")
    }

    @Test func `structured doctor finding keeps the caption before its affected formulae`() throws {
        let json = """
        {"tier": 1, "findings": [
          {"text": "Some installed formulae are deprecated or disabled.", "tier": 1,
           "affects": ["dotnet@6", "icu4c@77"], "links": [],
           "remediation": {"commands": [],
             "text": "You should find replacements for the following formulae:\\n\\n  dotnet@6\\n  icu4c@77\\n"}}
        ]}
        """
        let issue = try #require(DoctorJSONParser.parse(Data(json.utf8)).first)

        #expect(issue.blocks.first?.caption == "You should find replacements for the following formulae:")
    }
}
