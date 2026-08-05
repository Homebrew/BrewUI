//
//  PackageOperationObserver.swift
//  BrewCore
//

import Foundation

/// The operations that concern a single package: its own install/upgrade/uninstall, and any batch
/// `brew upgrade` that includes it. ``isOutdated`` feeds the bulk-coverage rule (see ``BrewUpgradeSelection/covers(packageID:isOutdated:)``).
public struct PackageOperationSubject: Hashable, Sendable {
    public let packageID: HomebrewPackageID
    public let isOutdated: Bool

    public init(packageID: HomebrewPackageID, isOutdated: Bool) {
        self.packageID = packageID
        self.isOutdated = isOutdated
    }

    public func includes(_ id: BrewOperationID) -> Bool {
        switch id {
        case let .package(packageID):
            packageID == self.packageID
        case let .bulkUpgrade(selection):
            selection.covers(packageID: packageID, isOutdated: isOutdated)
        case .maintenance:
            false
        }
    }
}

/// Observes the operation-phase timeline of a ``PackageOperationSubject`` across the command center's
/// combined stream, so any surface can drive "operation in progress" state without knowing how work is
/// scheduled. Callers fold the yielded phases through their own presentation rules.
public struct PackageOperationObserver: Sendable {
    private let commandCenter: any BrewCommandCenter

    public init(commandCenter: any BrewCommandCenter) {
        self.commandCenter = commandCenter
    }

    /// Phases of operations concerning `subject`. `allPhaseChanges()` has no replay, so the current running
    /// phase (if any) is yielded first from ``BrewCommandCenter/runningPhases()`` to catch work already in
    /// flight; subscribing before that snapshot means an event landing between the two is buffered, not lost.
    public func phases(for subject: PackageOperationSubject) -> AsyncStream<BrewOperationPhase> {
        AsyncStream { continuation in
            let task = Task {
                let stream = await commandCenter.allPhaseChanges()
                let running = await commandCenter.runningPhases()
                // Prefer the package's own operation over any covering bulk upgrade when both are tracked
                // as running: `runningPhases()` is an unordered dictionary, so seeding an arbitrary covering
                // entry could represent the wrong operation type (and miss the package op's initial `.running`,
                // which the replay-less stream never re-delivers) until the next transition.
                let seeded: BrewOperationPhase? = if let packagePhase = running[.package(subject.packageID)], packagePhase.isRunning {
                    packagePhase
                } else {
                    running.first(where: { subject.includes($0.key) && $0.value.isRunning })?.value
                }
                if let seeded {
                    continuation.yield(seeded)
                }
                for await (id, phase) in stream where subject.includes(id) {
                    continuation.yield(phase)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
