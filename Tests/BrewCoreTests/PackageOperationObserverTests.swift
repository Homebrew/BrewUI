//
//  PackageOperationObserverTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct PackageOperationObserverTests {
    private static let gitFormula = HomebrewPackageID.formula(name: "git")
    private static let wgetFormula = HomebrewPackageID.formula(name: "wget")
    private static let figmaCask = HomebrewPackageID.cask(token: "figma")

    private static func subject(
        _ packageID: HomebrewPackageID,
        outdated: Bool = false,
    ) -> PackageOperationSubject {
        PackageOperationSubject(packageID: packageID, isOutdated: outdated)
    }

    private static func collect(
        _ observer: PackageOperationObserver,
        _ subject: PackageOperationSubject,
    ) async -> [BrewOperationPhase] {
        var phases: [BrewOperationPhase] = []
        for await phase in observer.phases(for: subject) {
            phases.append(phase)
        }
        return phases
    }

    // MARK: - includes(_:)

    @Test func `includes matches the package's own id and covering bulk upgrades`() {
        let subject = Self.subject(Self.gitFormula, outdated: true)
        #expect(subject.includes(.package(Self.gitFormula)))
        #expect(!subject.includes(.package(Self.wgetFormula)))
        #expect(subject.includes(.bulkUpgrade(.all)))
        #expect(subject.includes(.bulkUpgrade(.formulae)))
        #expect(!subject.includes(.bulkUpgrade(.casks)))
    }

    @Test func `includes matches an explicit bulk upgrade by name even when the package is current`() {
        let subject = Self.subject(Self.gitFormula, outdated: false)
        #expect(!subject.includes(.bulkUpgrade(.all)))
        #expect(subject.includes(.bulkUpgrade(.explicit(["git"]))))
    }

    // MARK: - phases(for:)

    @Test func `seeds the running phase of work already in flight`() async {
        let center = FakeCommandCenter(running: [.package(Self.gitFormula): .running(.upgradeFormula)])
        let phases = await Self.collect(PackageOperationObserver(commandCenter: center), Self.subject(Self.gitFormula))
        #expect(phases == [.running(.upgradeFormula)])
    }

    @Test func `seeds the package's own operation over a covering bulk upgrade when both run`() async {
        // Both are tracked as running; the seed must reflect this package's own operation, not an
        // arbitrary covering entry, so the row shows the right operation type from the first phase.
        let center = FakeCommandCenter(running: [
            .package(Self.gitFormula): .running(.upgradeFormula),
            .bulkUpgrade(.all): .running(.upgradeAll),
        ])
        let phases = await Self.collect(
            PackageOperationObserver(commandCenter: center),
            Self.subject(Self.gitFormula, outdated: true),
        )
        #expect(phases == [.running(.upgradeFormula)])
    }

    @Test func `seeds a covering bulk upgrade when the package op is tracked but not running`() async {
        // A stale `.failed` package entry must not suppress seeding the covering bulk upgrade in flight.
        let center = FakeCommandCenter(running: [
            .package(Self.gitFormula): .failed(reason: .brewExecutableNotFound),
            .bulkUpgrade(.all): .running(.upgradeAll),
        ])
        let phases = await Self.collect(
            PackageOperationObserver(commandCenter: center),
            Self.subject(Self.gitFormula, outdated: true),
        )
        #expect(phases == [.running(.upgradeAll)])
    }

    @Test func `ignores operations for other packages`() async {
        let center = FakeCommandCenter(events: [(.package(Self.wgetFormula), .running(.upgradeFormula))])
        let phases = await Self.collect(PackageOperationObserver(commandCenter: center), Self.subject(Self.gitFormula))
        #expect(phases.isEmpty)
    }

    @Test func `yields a covering bulk upgrade in order`() async {
        let center = FakeCommandCenter(events: [
            (.bulkUpgrade(.all), .running(.upgradeAll)),
            (.bulkUpgrade(.all), .idle),
        ])
        let phases = await Self.collect(
            PackageOperationObserver(commandCenter: center),
            Self.subject(Self.gitFormula, outdated: true),
        )
        #expect(phases == [.running(.upgradeAll), .idle])
    }

    @Test func `ignores a bulk upgrade that does not cover the package`() async {
        let center = FakeCommandCenter(events: [(.bulkUpgrade(.formulae), .running(.upgradeAll))])
        let phases = await Self.collect(
            PackageOperationObserver(commandCenter: center),
            Self.subject(Self.figmaCask, outdated: true),
        )
        #expect(phases.isEmpty)
    }
}

private actor FakeCommandCenter: BrewCommandCenter {
    private let events: [(BrewOperationID, BrewOperationPhase)]
    private let running: [BrewOperationID: BrewOperationPhase]

    init(
        events: [(BrewOperationID, BrewOperationPhase)] = [],
        running: [BrewOperationID: BrewOperationPhase] = [:],
    ) {
        self.events = events
        self.running = running
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        running[id] ?? .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        running
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }

    @discardableResult
    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_: BrewCommand, id _: BrewOperationID) async throws {}
}
