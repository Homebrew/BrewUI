//
//  BrewUpgradeSelectionTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct BrewUpgradeSelectionTests {
    @Test func `all upgrades everything`() {
        #expect(BrewUpgradeSelection.all.arguments == ["upgrade"])
        #expect(BrewUpgradeSelection.all.displayCommand == "brew upgrade")
    }

    @Test func `formulae restricts to the formula flag`() {
        #expect(BrewUpgradeSelection.formulae.arguments == ["upgrade", "--formula"])
        #expect(BrewUpgradeSelection.formulae.displayCommand == "brew upgrade --formula")
    }

    @Test func `casks restricts to the cask flag`() {
        #expect(BrewUpgradeSelection.casks.arguments == ["upgrade", "--cask"])
        #expect(BrewUpgradeSelection.casks.displayCommand == "brew upgrade --cask")
    }

    @Test func `explicit lists the given names after upgrade`() {
        let selection = BrewUpgradeSelection.explicit(["git", "slack"])
        #expect(selection.arguments == ["upgrade", "git", "slack"])
        #expect(selection.displayCommand == "brew upgrade git slack")
    }

    @Test func `explicit with no names is just upgrade`() {
        // Defensive: the Upgrades tab never submits an empty explicit selection (the button is gated on a
        // non-zero visible count), but the value type should still be well-defined.
        let selection = BrewUpgradeSelection.explicit([])
        #expect(selection.arguments == ["upgrade"])
        #expect(selection.displayCommand == "brew upgrade")
    }

    @Test func `bulkUpgradeDisplayCommand mirrors the all selection`() {
        #expect(BrewOperationID.bulkUpgradeDisplayCommand == BrewUpgradeSelection.all.displayCommand)
    }

    @Test func `distinct selections produce distinct bulk upgrade ids`() {
        // Selection is part of the operation identity so the console can render each variant and distinct
        // batches don't dedupe against one another.
        #expect(BrewOperationID.bulkUpgrade(.all) != BrewOperationID.bulkUpgrade(.formulae))
        #expect(BrewOperationID.bulkUpgrade(.explicit(["git"])) != BrewOperationID.bulkUpgrade(.explicit(["wget"])))
        #expect(BrewOperationID.bulkUpgrade(.formulae) == BrewOperationID.bulkUpgrade(.formulae))
    }
}
