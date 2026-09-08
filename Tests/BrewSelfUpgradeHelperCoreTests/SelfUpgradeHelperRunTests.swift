//
//  SelfUpgradeHelperRunTests.swift
//  BrewSelfUpgradeHelperCoreTests
//

@testable import BrewSelfUpgradeHelperCore
import Foundation
import Testing

/// Nobody is watching while this runs, so a wrong order here is only visible afterwards — as an app that
/// came back at the old version, never came back, or came back twice.
struct SelfUpgradeHelperRunTests {
    // MARK: The app exits

    @Test func `an app that has already exited is upgraded, recorded and relaunched`() async {
        let effects = EffectRecorder(isAppRunning: false, upgradeSucceeds: true)

        let result = await makeRun(effects).run()

        #expect(result == .relaunched(upgraded: true))
        #expect(effects.upgradeCount == 1)
        #expect(effects.recordedOutcomes == [true])
        #expect(effects.relaunchCount == 1)
    }

    @Test func `a failed upgrade is still recorded and still relaunches`() async {
        let effects = EffectRecorder(isAppRunning: false, upgradeSucceeds: false)

        let result = await makeRun(effects).run()

        #expect(result == .relaunched(upgraded: false))
        #expect(effects.recordedOutcomes == [false])
        #expect(effects.relaunchCount == 1)
    }

    @Test func `the upgrade waits for the app rather than racing it`() async {
        let effects = EffectRecorder(isAppRunning: true, upgradeSucceeds: true)
        effects.stopRunningAfterPolls(3)

        let result = await makeRun(effects).run()

        #expect(result == .relaunched(upgraded: true))
        #expect(effects.livenessPollCount >= 4)
        #expect(effects.upgradeCount == 1)
    }

    /// The last sleep can carry the clock past the deadline while the app was already on its way out.
    @Test func `an app that exits on the deadline is not treated as a timeout`() async {
        let effects = EffectRecorder(isAppRunning: true, upgradeSucceeds: true)
        let clock = VirtualClock()
        effects.stopRunningAfterPolls(300)

        let result = await SelfUpgradeHelperRun(
            waitForExitTimeout: 30,
            pollInterval: .milliseconds(100),
            effects: effects.effects,
            now: { clock.now },
            sleep: { clock.advance(by: $0) },
        ).run()

        #expect(result == .relaunched(upgraded: true))
    }

    // MARK: The app does not exit

    /// The whole point: a timeout means the app is still on screen, so a relaunch would be a second copy
    /// of it, and there is no upgrade to acknowledge on a launch that never happens.
    @Test func `an app that outlives the wait is left alone`() async {
        let effects = EffectRecorder(isAppRunning: true, upgradeSucceeds: true)

        let result = await makeRun(effects).run()

        #expect(result == .abandoned)
        #expect(effects.upgradeCount == 0)
        #expect(effects.recordedOutcomes.isEmpty)
        #expect(effects.relaunchCount == 0)
    }

    @Test func `a timeout says so in the log`() async {
        let effects = EffectRecorder(isAppRunning: true, upgradeSucceeds: true)
        let transcript = TranscriptRecorder()

        _ = await makeRun(effects, log: { transcript.append($0) }).run()

        #expect(transcript.lines.contains { $0.contains("timed out") })
    }

    @Test func `the wait gives up after the timeout rather than polling forever`() async {
        let effects = EffectRecorder(isAppRunning: true, upgradeSucceeds: true)
        let clock = VirtualClock()

        _ = await SelfUpgradeHelperRun(
            waitForExitTimeout: 30,
            pollInterval: .milliseconds(100),
            effects: effects.effects,
            now: { clock.now },
            sleep: { clock.advance(by: $0) },
        ).run()

        #expect(clock.elapsed >= 30)
        #expect(clock.elapsed < 31)
    }

    // MARK: Ordering

    @Test func `the outcome is recorded before the relaunch, so the app comes back to a notice`() async {
        let effects = EffectRecorder(isAppRunning: false, upgradeSucceeds: true)

        _ = await makeRun(effects).run()

        #expect(effects.steps == ["upgrade", "record", "relaunch"])
    }

    // MARK: Support

    private func makeRun(
        _ effects: EffectRecorder,
        log: @escaping @Sendable (String) -> Void = { _ in },
    ) -> SelfUpgradeHelperRun {
        let clock = VirtualClock()
        return SelfUpgradeHelperRun(
            waitForExitTimeout: 30,
            pollInterval: .milliseconds(100),
            effects: effects.effects,
            log: log,
            now: { clock.now },
            sleep: { clock.advance(by: $0) },
        )
    }
}

// MARK: - Support

/// Advanced by the run's own `sleep`, so the wait resolves without the test spending 30 real seconds in it.
// swiftlint:disable:next unchecked_sendable
private final class VirtualClock: @unchecked Sendable {
    private let lock = NSLock()
    private let start = Date(timeIntervalSince1970: 0)
    private var offset: TimeInterval = 0

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return start.addingTimeInterval(offset)
    }

    var elapsed: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return offset
    }

    func advance(by duration: Duration) {
        lock.lock()
        defer { lock.unlock() }
        offset += TimeInterval(duration.components.seconds)
            + TimeInterval(duration.components.attoseconds) / 1e18
    }
}

// swiftlint:disable:next unchecked_sendable
private final class EffectRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var running: Bool
    private let upgradeSucceeds: Bool
    private var pollsBeforeExit: Int?
    private var polls = 0
    private var upgrades = 0
    private var outcomes: [Bool] = []
    private var relaunches = 0
    private var order: [String] = []

    init(isAppRunning: Bool, upgradeSucceeds: Bool) {
        running = isAppRunning
        self.upgradeSucceeds = upgradeSucceeds
    }

    /// The app quits partway through the wait, which is the ordinary case.
    func stopRunningAfterPolls(_ count: Int) {
        lock.lock()
        defer { lock.unlock() }
        pollsBeforeExit = count
    }

    var livenessPollCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return polls
    }

    var upgradeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return upgrades
    }

    var recordedOutcomes: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return outcomes
    }

    var relaunchCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return relaunches
    }

    var steps: [String] {
        lock.lock()
        defer { lock.unlock() }
        return order
    }

    var effects: SelfUpgradeHelperRun.Effects {
        SelfUpgradeHelperRun.Effects(
            isAppRunning: { [self] in isRunning() },
            upgrade: { [self] in upgrade() },
            recordOutcome: { [self] in record($0) },
            relaunchApp: { [self] in relaunch() },
        )
    }

    private func isRunning() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        polls += 1
        if let pollsBeforeExit, polls > pollsBeforeExit {
            running = false
        }
        return running
    }

    private func upgrade() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        upgrades += 1
        order.append("upgrade")
        return upgradeSucceeds
    }

    private func record(_ succeeded: Bool) {
        lock.lock()
        defer { lock.unlock() }
        outcomes.append(succeeded)
        order.append("record")
    }

    private func relaunch() {
        lock.lock()
        defer { lock.unlock() }
        relaunches += 1
        order.append("relaunch")
    }
}

// swiftlint:disable:next unchecked_sendable
private final class TranscriptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(line)
    }
}
