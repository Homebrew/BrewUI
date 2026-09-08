//
//  SelfUpgradeCoordinatorTests.swift
//  BrewFeatureSelfUpgradeTests
//

import BrewCore
@testable import BrewFeatureSelfUpgrade
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct SelfUpgradeCoordinatorTests {
    private func status(available: Bool, latest: String? = "1.5.0") -> SelfUpgradeStatus {
        SelfUpgradeStatus(
            runningVersion: "1.4.2",
            latestVersion: latest,
            homepageURL: SelfUpgradeIdentity.homepageURL,
            isUpgradeAvailable: available,
        )
    }

    private func makeCoordinator(
        status: SelfUpgradeStatus,
        preferences: StubSelfUpgradePreferences = StubSelfUpgradePreferences(),
        handoff: any SelfUpgradeHandoff = RecordingSelfUpgradeHandoff(),
    ) -> SelfUpgradeCoordinator {
        SelfUpgradeCoordinator(
            statusProvider: StubSelfUpgradeStatusProvider(selfUpgradeStatus: status),
            preferences: preferences,
            handoff: handoff,
        )
    }

    // MARK: Banner visibility & dismissal

    @Test func `banner is visible when an undismissed update is available`() {
        let coordinator = makeCoordinator(status: status(available: true))
        #expect(coordinator.isUpgradeAvailable)
        #expect(coordinator.isBannerVisible)
    }

    @Test func `banner is hidden when no update is available`() {
        let coordinator = makeCoordinator(status: status(available: false))
        #expect(coordinator.isBannerVisible == false)
    }

    @Test func `dismiss hides the banner for the current version and records it`() {
        let preferences = StubSelfUpgradePreferences()
        let coordinator = makeCoordinator(status: status(available: true), preferences: preferences)

        coordinator.dismiss()

        #expect(preferences.dismissedVersion == "1.5.0")
        #expect(coordinator.isBannerVisible == false)
    }

    @Test func `banner reappears when a newer version ships after dismissal`() {
        let preferences = StubSelfUpgradePreferences(dismissedVersion: "1.5.0")
        let coordinator = makeCoordinator(status: status(available: true, latest: "1.6.0"), preferences: preferences)
        #expect(coordinator.isBannerVisible)
    }

    // MARK: An update with no version string

    /// `brew` can report the app's cask as outdated without a version to go with it. The banner has copy
    /// for that, so it has to be reachable rather than reading as an already-dismissed update.
    @Test func `banner is visible for an update brew reports without a version`() {
        let coordinator = makeCoordinator(status: status(available: true, latest: nil))
        #expect(coordinator.isBannerVisible)
    }

    @Test func `a version-less update is not hidden by a dismissal of some earlier version`() {
        let preferences = StubSelfUpgradePreferences(dismissedVersion: "1.5.0")
        let coordinator = makeCoordinator(status: status(available: true, latest: nil), preferences: preferences)
        #expect(coordinator.isBannerVisible)
    }

    @Test func `dismissing a version-less update hides the banner without storing a version`() {
        let preferences = StubSelfUpgradePreferences()
        let coordinator = makeCoordinator(status: status(available: true, latest: nil), preferences: preferences)

        coordinator.dismiss()

        #expect(coordinator.isBannerVisible == false)
        #expect(preferences.dismissedVersion == nil)
    }

    /// The session-only dismissal must not leak into a later release that does carry a version.
    @Test func `dismissing a version-less update leaves a versioned one still stored as undismissed`() {
        let preferences = StubSelfUpgradePreferences()
        let statusProvider = StubSelfUpgradeStatusProvider(selfUpgradeStatus: status(available: true, latest: nil))
        let coordinator = SelfUpgradeCoordinator(
            statusProvider: statusProvider,
            preferences: preferences,
            handoff: RecordingSelfUpgradeHandoff(),
        )
        coordinator.dismiss()
        #expect(coordinator.isBannerVisible == false)

        statusProvider.selfUpgradeStatus = status(available: true, latest: "1.6.0")

        #expect(coordinator.isBannerVisible)
    }

    // MARK: beginUpgrade

    @Test func `beginUpgrade invokes the handoff and returns to idle when it does not terminate`() async {
        let handoff = RecordingSelfUpgradeHandoff()
        let coordinator = makeCoordinator(status: status(available: true), handoff: handoff)

        await coordinator.beginUpgrade()

        #expect(handoff.performCount == 1)
        #expect(coordinator.phase == .idle)
    }

    @Test func `beginUpgrade surfaces a handoff failure in the phase`() async {
        let handoff = RecordingSelfUpgradeHandoff(error: TestHandoffError())
        let coordinator = makeCoordinator(status: status(available: true), handoff: handoff)

        await coordinator.beginUpgrade()

        #expect(handoff.performCount == 1)
        #expect(coordinator.phase == .failed(TestHandoffError.message))
    }

    @Test func `beginUpgrade does nothing when no update is available`() async {
        let handoff = RecordingSelfUpgradeHandoff()
        let coordinator = makeCoordinator(status: status(available: false), handoff: handoff)

        await coordinator.beginUpgrade()

        #expect(handoff.performCount == 0)
        #expect(coordinator.phase == .idle)
    }

    // MARK: Detail action state

    @Test func `the upgrade action is enabled only when there is an upgrade to run`() {
        #expect(makeCoordinator(status: status(available: true)).isUpgradeActionEnabled)
        #expect(makeCoordinator(status: status(available: false)).isUpgradeActionEnabled == false)
    }

    /// Both buttons go down together: "Later" defers an upgrade, which means nothing once one is under way.
    @Test func `the upgrade action reports progress while the handoff is in flight`() async {
        let handoff = SuspendingSelfUpgradeHandoff()
        let coordinator = makeCoordinator(status: status(available: true), handoff: handoff)
        #expect(coordinator.isUpgradeInProgress == false)

        let update = Task { await coordinator.beginUpgrade() }
        await Self.waitUntil { handoff.isSuspended }

        #expect(coordinator.isUpgradeInProgress)
        #expect(coordinator.isUpgradeActionEnabled == false)

        handoff.resume()
        await update.value
        #expect(coordinator.isUpgradeInProgress == false)
        #expect(coordinator.isUpgradeActionEnabled)
    }

    @Test func `there is no failure message until a handoff fails`() async {
        let coordinator = makeCoordinator(status: status(available: true))
        #expect(coordinator.failureMessage == nil)

        await coordinator.beginUpgrade()
        #expect(coordinator.failureMessage == nil)
    }

    @Test func `a failed handoff exposes its message`() async {
        let handoff = RecordingSelfUpgradeHandoff(error: TestHandoffError())
        let coordinator = makeCoordinator(status: status(available: true), handoff: handoff)

        await coordinator.beginUpgrade()

        #expect(coordinator.failureMessage == TestHandoffError.message)
    }

    // MARK: Launch outcome

    @Test func `register launch outcome drives the one-time completion flag`() {
        let coordinator = makeCoordinator(status: status(available: false))
        #expect(coordinator.didJustCompleteUpgrade == false)

        coordinator.registerLaunchOutcome(.succeeded)
        #expect(coordinator.didJustCompleteUpgrade)
        #expect(coordinator.didJustFailUpgrade == false)

        coordinator.acknowledgeUpgradeCompletion()
        #expect(coordinator.didJustCompleteUpgrade == false)
    }

    @Test func `a failed launch outcome is reported separately from success`() {
        let coordinator = makeCoordinator(status: status(available: true))
        coordinator.registerLaunchOutcome(.failed)

        #expect(coordinator.didJustFailUpgrade)
        #expect(coordinator.didJustCompleteUpgrade == false)

        coordinator.acknowledgeUpgradeCompletion()
        #expect(coordinator.didJustFailUpgrade == false)
    }

    @Test func `registering a non-self-upgrade launch leaves both flags clear`() {
        let coordinator = makeCoordinator(status: status(available: true))
        coordinator.registerLaunchOutcome(nil)

        #expect(coordinator.lastLaunchOutcome == nil)
        #expect(coordinator.didJustCompleteUpgrade == false)
        #expect(coordinator.didJustFailUpgrade == false)
    }

    /// Bounded so a regression fails the caller's assertion rather than hanging the suite.
    private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            await Task.yield()
        }
    }
}

/// Parks inside `performUpgrade` so the coordinator can be observed mid-handoff.
@MainActor
private final class SuspendingSelfUpgradeHandoff: SelfUpgradeHandoff {
    private(set) var isSuspended = false
    private var continuation: CheckedContinuation<Void, Never>?

    func performUpgrade() async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            isSuspended = true
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
        isSuspended = false
    }
}

private struct TestHandoffError: LocalizedError {
    static let message = "helper could not start"
    var errorDescription: String? {
        Self.message
    }
}
