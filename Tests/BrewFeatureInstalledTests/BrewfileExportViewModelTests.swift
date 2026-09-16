//
//  BrewfileExportViewModelTests.swift
//  BrewFeatureInstalledTests
//

import BrewCore
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct BrewfileExportViewModelTests {
    private let destination = URL(filePath: "/tmp/Brewfile")

    @Test func `openSheet starts awaiting a destination`() {
        let viewModel = makeViewModel()
        viewModel.openSheet()
        #expect(viewModel.isSheetPresented)
        #expect(viewModel.presentation == .awaitingDestination)
        #expect(!viewModel.canSubmit)
        #expect(viewModel.canChooseLocation)
        #expect(viewModel.canDismiss)
        #expect(viewModel.dismissButtonTitle == "Cancel")
    }

    @Test func `acceptDestination becomes ready with the copyable command`() {
        let viewModel = makeViewModel()
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        #expect(viewModel.canSubmit)
        #expect(viewModel.currentItem?.destinationPath == "/tmp/Brewfile")
        #expect(
            viewModel.currentItem?.displayCommand ==
                "brew bundle dump --file=/tmp/Brewfile --force --formula --cask --tap",
        )
        #expect(viewModel.presentation == .ready(BrewfileExportItem(destinationURL: destination)))
    }

    @Test func `save panel cancellation is a no-op`() {
        let viewModel = makeViewModel()
        viewModel.openSheet()
        #expect(viewModel.presentation == .awaitingDestination)
        #expect(viewModel.currentItem == nil)
    }

    @Test func `export succeeds and reveals the destination`() async {
        let center = ExportRecordingCommandCenter()
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({
            if case .exported = viewModel.presentation { return true }
            return false
        }, message: "expected export success")

        #expect(viewModel.canRevealInFinder)
        #expect(viewModel.dismissButtonTitle == "Done")
        #expect(!viewModel.canSubmit)
        #expect(!viewModel.canChooseLocation)
        #expect(viewModel.currentItem?.destinationPath == "/tmp/Brewfile")

        let recorded = await center.recordedEntries
        #expect(recorded.count == 1)
        #expect(recorded.first?.command.operationKind == .bundleDump)
        #expect(recorded.first?.command.arguments == [
            "bundle",
            "dump",
            "--file=/tmp/Brewfile",
            "--force",
            "--formula",
            "--cask",
            "--tap",
        ])
        #expect(recorded.first?.id == BrewfileExportItem(destinationURL: destination).operationID)
    }

    @Test func `export failure keeps the destination and is retryable`() async {
        let center = ExportThrowingCommandCenter(
            error: BrewCommandError.failed(exitCode: 1, stderr: "Dump failed"),
        )
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({
            if case .failed = viewModel.presentation { return true }
            return false
        }, message: "expected export failure")

        #expect(viewModel.failureMessage == "Dump failed")
        #expect(viewModel.canSubmit)
        #expect(viewModel.canChooseLocation)
        #expect(viewModel.currentItem?.destinationPath == "/tmp/Brewfile")
        #expect(!viewModel.canRevealInFinder)
    }

    @Test func `retry after failure submits again`() async {
        let center = ExportThrowingThenSucceedingCommandCenter(
            error: BrewCommandError.failed(exitCode: 1, stderr: "Dump failed"),
        )
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({
            if case .failed = viewModel.presentation { return true }
            return false
        }, message: "expected first export to fail")

        viewModel.export()
        await waitUntil({
            if case .exported = viewModel.presentation { return true }
            return false
        }, message: "expected retry to succeed")

        #expect(await center.submitCallCount == 2)
        #expect(viewModel.canRevealInFinder)
        #expect(viewModel.failureMessage == nil)
    }

    @Test func `failure prefers the tracked command-center phase message`() async {
        let center = ExportFailedPhaseCommandCenter(
            message: "Brewfile already exists",
        )
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({
            if case .failed = viewModel.presentation { return true }
            return false
        }, message: "expected export failure from tracked phase")

        #expect(viewModel.failureMessage == "Brewfile already exists")
        #expect(viewModel.currentItem?.destinationPath == "/tmp/Brewfile")
    }

    @Test func `duplicate submit is ignored while exporting`() async {
        let center = ExportDeferredCommandCenter()
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({ viewModel.isRunning }, message: "expected export to start")
        await center.waitForSubmitCallCount(1)
        viewModel.export()
        #expect(await center.submitCallCount == 1)
        #expect(!viewModel.canSubmit)
        #expect(!viewModel.canChooseLocation)
        await center.resolve()
        await waitUntil({
            if case .exported = viewModel.presentation { return true }
            return false
        }, message: "expected deferred export to finish")
    }

    @Test func `destination changes are ignored while exporting`() async {
        let center = ExportDeferredCommandCenter()
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({ viewModel.isRunning }, message: "expected export to start")
        await center.waitForSubmitCallCount(1)
        viewModel.acceptDestination(URL(filePath: "/tmp/Other"))
        #expect(viewModel.currentItem?.destinationPath == "/tmp/Brewfile")
        await center.resolve()
        await waitUntil({ !viewModel.isRunning }, message: "expected export to finish")
    }

    @Test func `dismiss is ignored while exporting`() async {
        let center = ExportDeferredCommandCenter()
        let viewModel = makeViewModel(center: center)
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.export()
        await waitUntil({ viewModel.isRunning }, message: "expected export to start")
        await center.waitForSubmitCallCount(1)
        viewModel.requestDismiss()
        #expect(viewModel.isSheetPresented)
        #expect(viewModel.isRunning)
        await center.resolve()
        await waitUntil({ !viewModel.isRunning }, message: "expected export to finish")
    }

    @Test func `dismiss when idle closes and resets`() {
        let viewModel = makeViewModel()
        viewModel.openSheet()
        viewModel.acceptDestination(destination)
        viewModel.requestDismiss()
        #expect(!viewModel.isSheetPresented)
        #expect(viewModel.presentation == .awaitingDestination)
        #expect(viewModel.currentItem == nil)
    }

    private func makeViewModel(
        center: any BrewCommandCenter = ExportRecordingCommandCenter(),
    ) -> BrewfileExportViewModel {
        BrewfileExportViewModel(
            brewCommandCenter: center,
            commandFactory: StubMutatingCommandFactory(),
        )
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool, message: String) async {
    for _ in 0 ..< 400 {
        if condition() {
            return
        }
        await Task.yield()
    }
    Issue.record(message)
}

private actor ExportRecordingCommandCenter: BrewCommandCenter {
    private(set) var recordedEntries: [(id: BrewOperationID, command: BrewCommand)] = []

    func phase(for _: BrewOperationID) async -> BrewOperationPhase { .idle }
    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] { [:] }

    func capture(_ command: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        recordedEntries.append((id, command))
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}

private actor ExportThrowingCommandCenter: BrewCommandCenter {
    let error: Error
    init(error: Error) {
        self.error = error
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase { .idle }
    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] { [:] }

    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        throw error
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}

private actor ExportThrowingThenSucceedingCommandCenter: BrewCommandCenter {
    let error: Error
    private(set) var submitCallCount = 0
    init(error: Error) {
        self.error = error
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase { .idle }
    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] { [:] }

    func capture(_ command: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        _ = command
        submitCallCount += 1
        if submitCallCount == 1 {
            throw error
        }
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}

private actor ExportFailedPhaseCommandCenter: BrewCommandCenter {
    let message: String
    private var tracked: [BrewOperationID: BrewOperationPhase] = [:]

    init(message: String) {
        self.message = message
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        tracked[id] ?? .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] { [:] }

    func capture(_: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        let failure = OperationFailure.brewCommand(exitCode: 1, stderr: message)
        tracked[id] = .failed(reason: failure)
        throw BrewCommandError.failed(exitCode: 1, stderr: "ignored")
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}

private actor ExportDeferredCommandCenter: BrewCommandCenter {
    private(set) var submitCallCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func phase(for _: BrewOperationID) async -> BrewOperationPhase { .idle }
    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] { [:] }

    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        submitCallCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }

    func resolve() {
        continuation?.resume()
        continuation = nil
    }

    func waitForSubmitCallCount(_ expected: Int) async {
        for _ in 0 ..< 1000 {
            if submitCallCount >= expected { return }
            await Task.yield()
        }
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}
