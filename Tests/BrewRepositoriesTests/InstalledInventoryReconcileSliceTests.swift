//
//  InstalledInventoryReconcileSliceTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

/// Serves a fresh `brew info --installed` payload per call, so a test can tell the snapshot taken
/// before a mutation apart from the one the reconcile fetches.
private actor SequencedInventoryRunner: BrewCommandRunning {
    private let mutationArgv: [String]
    private let mutationOutput: CommandOutput
    private let inventoryResponses: [CommandOutput]
    private(set) var inventoryCallCount = 0

    init(mutationArgv: [String], mutationOutput: CommandOutput, inventoryResponses: [CommandOutput]) {
        self.mutationArgv = mutationArgv
        self.mutationOutput = mutationOutput
        self.inventoryResponses = inventoryResponses
    }

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        if arguments == mutationArgv {
            return mutationOutput
        }
        guard arguments == ["info", "--installed", "--json=v2"] else {
            throw BrewCommandError.failed(exitCode: 99, stderr: "unmocked: \(arguments.joined(separator: " "))")
        }
        inventoryCallCount += 1
        return inventoryResponses[min(inventoryCallCount - 1, inventoryResponses.count - 1)]
    }
}

private func inventoryJSON(helloOutdated: Bool) -> String {
    """
    {
      "formulae": [
        {
          "name": "hello",
          "full_name": "hello",
          "installed": [{ "version": "2.12.1" }],
          "outdated": \(helloOutdated)
        }
      ],
      "casks": []
    }
    """
}

private func inventory(helloOutdated: Bool) -> CommandOutput {
    CommandOutput(standardOutput: inventoryJSON(helloOutdated: helloOutdated), standardError: "", terminationStatus: 0)
}

/// Wires a real command center over the same runner the repository uses, so these tests exercise the
/// production settling path rather than a hand-fed phase timeline.
private func makeCenter(
    runner: any BrewCommandRunning,
    reconciler: any BrewOperationReconciling,
) -> SerialBrewCommandCenter {
    let context = BrewCommandExecutionContext(
        commandRunner: runner,
        locator: BrewExecutableLocator(overrideURL: InstalledPackagesTestSupport.fakeBrewExecutableURL),
    )
    return SerialBrewCommandCenter(executionContext: context, reconciler: reconciler)
}

struct InstalledInventoryReconcileSliceTests {
    @Test @MainActor func `a batch upgrade that fails overall still clears the badge it did fix`() async {
        // Reported bug: `brew upgrade hello world` exits non-zero having upgraded `hello`, and the
        // inventory refreshed only on success, so `hello` stayed marked outdated until a manual refresh.
        let runner = SequencedInventoryRunner(
            mutationArgv: ["upgrade", "hello", "world"],
            mutationOutput: CommandOutput(
                standardOutput: "",
                standardError: #"Error: No available formula with the name "world""#,
                terminationStatus: 1,
            ),
            inventoryResponses: [inventory(helloOutdated: true), inventory(helloOutdated: false)],
        )
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let center = makeCenter(runner: runner, reconciler: repository)
        await repository.load(forceRefresh: true)
        #expect(repository.info(for: .formula(name: "hello"))?.outdated == true)

        let id = BrewOperationID.bulkUpgrade(.all)
        await #expect(throws: (any Error).self) {
            try await center.perform(
                BrewCommand(operationKind: .upgradeAll, arguments: ["upgrade", "hello", "world"]),
                id: id,
            )
        }

        #expect(repository.info(for: .formula(name: "hello"))?.outdated == false)
    }

    @Test @MainActor func `an inventory refresh that fails still settles the operation`() async throws {
        // Reported bug: busy chrome waited for new package data, so a refresh that itself failed left
        // Installed rows spinning "Uninstalling..." with nothing left to release them.
        let runner = SequencedInventoryRunner(
            mutationArgv: ["uninstall", "hello"],
            mutationOutput: CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0),
            inventoryResponses: [
                inventory(helloOutdated: false),
                CommandOutput(standardOutput: "", standardError: "Error: unreachable", terminationStatus: 1),
            ],
        )
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let center = makeCenter(runner: runner, reconciler: repository)
        await repository.load(forceRefresh: true)

        let id = BrewOperationID(kind: .formula, name: "hello")
        try await center.perform(BrewCommand(operationKind: .uninstallFormula, arguments: ["uninstall", "hello"]), id: id)

        let phase = await center.phase(for: id)
        #expect(repository.refreshFailure != nil)
        // Busy chrome is a pure function of these two, so a settled phase is the row spinner stopping.
        #expect(phase.isSettled)
        #expect(phase.activeKind == nil)
    }
}
