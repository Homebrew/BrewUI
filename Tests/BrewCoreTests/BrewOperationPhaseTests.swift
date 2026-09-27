//
//  BrewOperationPhaseTests.swift
//  BrewTests
//

import BrewCore
import Testing

struct BrewOperationPhaseTests {
    @Test(arguments: [
        BrewOperationPhase.running(.installFormula),
        .running(.upgradeAll),
        .reconciling(.uninstallFormula),
        .reconciling(.upgradeApp),
    ])
    func `a mutating phase that has not settled is unfinished`(phase: BrewOperationPhase) {
        #expect(phase.isUnfinishedMutation)
    }

    @Test(arguments: [
        BrewOperationPhase.idle,
        .failed(reason: OperationFailure(description: "boom")),
        .running(.doctorRead),
    ])
    func `a settled or read-only phase is not an unfinished mutation`(phase: BrewOperationPhase) {
        #expect(!phase.isUnfinishedMutation)
    }
}
