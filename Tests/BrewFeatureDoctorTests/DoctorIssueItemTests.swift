//
//  DoctorIssueItemTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureDoctor
import Foundation
import Testing

@MainActor
struct DoctorIssueItemTests {
    // MARK: - Block factories

    /// A single non-admin `brew` step block — the only shape ``DoctorBlock/isRunnable`` accepts.
    private static func runnable(id: Int, command: String, arguments: [String]) -> DoctorBlock {
        DoctorBlock(
            id: id,
            caption: nil,
            content: .command([
                DoctorFixStep(displayCommand: command, arguments: arguments, needsAdmin: false),
            ]),
        )
    }

    /// A `sudo` step — not runnable (copy-only) because it needs admin.
    private static func adminCommand(id: Int) -> DoctorBlock {
        DoctorBlock(
            id: id,
            caption: nil,
            content: .command([
                DoctorFixStep(displayCommand: "sudo chown -R me /opt/homebrew", arguments: nil, needsAdmin: true),
            ]),
        )
    }

    /// A two-step command block — not runnable because only single-step blocks can be submitted.
    private static func multiStep(id: Int) -> DoctorBlock {
        DoctorBlock(
            id: id,
            caption: nil,
            content: .command([
                DoctorFixStep(displayCommand: "brew update", arguments: ["update"], needsAdmin: false),
                DoctorFixStep(displayCommand: "brew upgrade", arguments: ["upgrade"], needsAdmin: false),
            ]),
        )
    }

    private static func prose(id: Int) -> DoctorBlock {
        DoctorBlock(id: id, caption: nil, content: .prose(["Some explanatory text."]))
    }

    private static func data(id: Int) -> DoctorBlock {
        DoctorBlock(id: id, caption: nil, content: .data(["macvim"]))
    }

    private static func issue(
        title: String = "Title",
        severity: DoctorSeverity = .caution,
        blocks: [DoctorBlock] = [],
        rawBody: String = "",
    ) -> DoctorIssue {
        DoctorIssue(title: title, severity: severity, blocks: blocks, rawBody: rawBody)
    }

    // MARK: - init

    @Test func `init copies the issue's presentation fields verbatim`() {
        let blocks = [Self.prose(id: 0), Self.runnable(id: 1, command: "brew cleanup", arguments: ["cleanup"])]
        let source = Self.issue(title: "Stale downloads", severity: .danger, blocks: blocks, rawBody: "raw")
        let item = DoctorIssueItem(issue: source)

        #expect(item.title == "Stale downloads")
        #expect(item.severity == .danger)
        #expect(item.blocks == blocks)
        #expect(item.rawBody == "raw")
        #expect(item.id == DoctorIssueItem.contentID(for: source))
    }

    // MARK: - contentID

    @Test func `contentID is deterministic for the same content`() {
        let source = Self.issue(title: "Same", rawBody: "body")
        #expect(DoctorIssueItem.contentID(for: source) == DoctorIssueItem.contentID(for: source))
    }

    @Test func `contentID changes when the title changes`() {
        let a = Self.issue(title: "Title A", rawBody: "shared")
        let b = Self.issue(title: "Title B", rawBody: "shared")
        #expect(DoctorIssueItem.contentID(for: a) != DoctorIssueItem.contentID(for: b))
    }

    @Test func `contentID changes when the raw body changes`() {
        let a = Self.issue(title: "shared", rawBody: "Body A")
        let b = Self.issue(title: "shared", rawBody: "Body B")
        #expect(DoctorIssueItem.contentID(for: a) != DoctorIssueItem.contentID(for: b))
    }

    @Test func `contentID ignores severity and blocks`() {
        // Two issues with identical title/rawBody but different severity and blocks hash equal —
        // the id tracks SwiftUI selection by issue identity, which is the title+body pair only.
        let a = Self.issue(title: "t", severity: .caution, blocks: [Self.prose(id: 0)], rawBody: "b")
        let b = Self.issue(title: "t", severity: .danger, blocks: [Self.data(id: 0)], rawBody: "b")
        #expect(DoctorIssueItem.contentID(for: a) == DoctorIssueItem.contentID(for: b))
    }

    @Test func `contentID separates the title from the body`() {
        // The `\n` join means a title/body boundary shift can't collide: "a"+"b" must differ from "ab"+"".
        let split = Self.issue(title: "a", rawBody: "b")
        let merged = Self.issue(title: "ab", rawBody: "")
        #expect(DoctorIssueItem.contentID(for: split) != DoctorIssueItem.contentID(for: merged))
    }

    // MARK: - primaryRunnableBlock / primaryRunnableStep

    @Test func `primaryRunnableBlock returns the first runnable block, skipping non-runnable ones`() {
        let item = DoctorIssueItem(issue: Self.issue(blocks: [
            Self.prose(id: 0),
            Self.adminCommand(id: 1),
            Self.multiStep(id: 2),
            Self.runnable(id: 3, command: "brew link openssl@3", arguments: ["link", "openssl@3"]),
            Self.runnable(id: 4, command: "brew cleanup", arguments: ["cleanup"]),
        ]))
        #expect(item.primaryRunnableBlock?.id == 3)
        #expect(item.primaryRunnableStep?.displayCommand == "brew link openssl@3")
        #expect(item.primaryRunnableStep?.arguments == ["link", "openssl@3"])
    }

    @Test func `primaryRunnableBlock is nil when no block is runnable`() {
        let item = DoctorIssueItem(issue: Self.issue(blocks: [
            Self.prose(id: 0),
            Self.data(id: 1),
            Self.adminCommand(id: 2),
            Self.multiStep(id: 3),
        ]))
        #expect(item.primaryRunnableBlock == nil)
        #expect(item.primaryRunnableStep == nil)
    }

    // MARK: - hasRunnableFix / fixToken

    @Test func `hasRunnableFix and fixToken reflect a runnable block`() {
        let item = DoctorIssueItem(issue: Self.issue(blocks: [
            Self.runnable(id: 0, command: "brew cleanup", arguments: ["cleanup"]),
        ]))
        #expect(item.hasRunnableFix == true)
        #expect(item.fixToken == "brew cleanup")
    }

    @Test func `hasRunnableFix and fixToken are empty when nothing is runnable`() {
        let item = DoctorIssueItem(issue: Self.issue(blocks: [Self.data(id: 0)]))
        #expect(item.hasRunnableFix == false)
        #expect(item.fixToken == nil)
    }

    // MARK: - accessibilityLabel

    @Test func `accessibilityLabel appends Fix available when a fix is runnable`() {
        let item = DoctorIssueItem(issue: Self.issue(
            title: "Unlinked kegs",
            blocks: [Self.runnable(id: 0, command: "brew link x", arguments: ["link", "x"])],
        ))
        #expect(item.accessibilityLabel == "Unlinked kegs, Fix available")
    }

    @Test func `accessibilityLabel is just the title when no fix is available`() {
        let item = DoctorIssueItem(issue: Self.issue(title: "Deprecated formulae", blocks: [Self.data(id: 0)]))
        #expect(item.accessibilityLabel == "Deprecated formulae")
    }
}
