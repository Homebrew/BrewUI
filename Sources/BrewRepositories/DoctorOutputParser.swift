//
//  DoctorOutputParser.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// Pure text→domain parser for `brew doctor` output. No dependencies, no isolation — unit-tested directly.
///
/// Each warning is parsed into an ordered list of typed ``DoctorBlock``s (`.prose` / `.command` /
/// `.data` / `.link`), each keeping the colon-introduced caption that produced it. Classification of an
/// indented block follows the first-member rule from
/// `.ai/plans/DoctorParsing-Plan-Addendum.md`: a `dataNounCue` guard forces `.data` *before* the
/// first-member command test for lists whose first item could read as a command; otherwise the first
/// member's content (command / link / else) decides the mode. The executable allowlist is consulted
/// once per block plus as a `.prose` fallback for stray commands sitting under period-ending prose.
public enum DoctorOutputParser {
    public static func parse(_ output: String) -> DoctorReport {
        let blocks = warningBlocks(in: output)
        return DoctorReport(issues: blocks.compactMap { block in
            var parser = WarningBlockParser(block: block)
            return parser.parse()
        })
    }
}

// MARK: - Block splitting

private struct WarningBlock {
    var title: String
    var bodyLines: [String]
}

private func warningBlocks(in output: String) -> [WarningBlock] {
    var blocks: [WarningBlock] = []
    var current: WarningBlock?
    for line in output.components(separatedBy: "\n") {
        if line.hasPrefix("Warning:") {
            if let current {
                blocks.append(current)
            }
            let title = String(line.dropFirst("Warning:".count)).trimmingCharacters(in: .whitespaces)
            current = WarningBlock(title: title, bodyLines: [])
        } else if current != nil {
            current?.bodyLines.append(line)
        }
    }
    if let current {
        blocks.append(current)
    }
    return blocks
}

// MARK: - Per-warning state machine

private struct BlockBuilder {
    var type: DoctorBlockType
    var caption: String?
    var precededByBlankLine: Bool = false
    var proseLines: [String] = []
    var commandSteps: [DoctorFixStep] = []
    var dataItems: [String] = []
    var linkItems: [DoctorLink] = []
}

private struct WarningBlockParser {
    let block: WarningBlock
    var committed: [DoctorBlock] = []
    var current: BlockBuilder?
    var inlineChips: [DoctorBacktickChip] = []
    /// Set when a colon-terminated un-indented line is seen and we're waiting for its first indented
    /// member to decide the block's type.
    var pendingCaption: String?
    /// `true` while a special intro (`do not exist:` / `not writable by your user:`) is allowing
    /// un-indented item lines to flow into a data block.
    var specialUnindentedActive: Bool
    /// Set when an empty un-indented line is processed; captured by the next ``BlockBuilder`` started
    /// after the gap. Drives the wider paragraph-break gap in the detail view.
    var nextBlockFollowsBlankLine: Bool = false

    init(block: WarningBlock) {
        self.block = block
        // The title can itself be the colon intro for the first body block (e.g.
        // `Warning: The following directories are not writable by your user:`).
        let titleIsIntro = block.title.hasSuffix(":")
        pendingCaption = titleIsIntro ? block.title : nil
        specialUnindentedActive = titleIsIntro && acceptsUnindentedItems(block.title)
    }

    mutating func parse() -> DoctorIssue? {
        guard !block.title.isEmpty else {
            return nil
        }
        for line in block.bodyLines {
            processLine(line)
        }
        flushCurrent()
        mergeSameParagraphCaptionsIntoProse()

        let rawBody = block.bodyLines.joined(separator: "\n")
        return DoctorIssue(
            title: block.title,
            severity: parseSeverity(body: rawBody),
            section: classifySection(title: block.title, body: rawBody),
            blocks: committed,
            inlineChips: uniqueChips(inlineChips),
            rawBody: rawBody,
        )
    }

    /// When a non-prose block carries a colon-introduced caption and was not separated from a preceding
    /// prose block by a blank line, brew was writing one continuous paragraph that ends with the caption
    /// leading into the affordance. Fold the caption back onto the prose so the detail view renders the
    /// whole paragraph in one ``Text`` (with native line height) and the affordance card sits below with
    /// the standard element-transition gap.
    private mutating func mergeSameParagraphCaptionsIntoProse() {
        guard committed.count > 1 else {
            return
        }
        for index in 1 ..< committed.count {
            let current = committed[index]
            let prior = committed[index - 1]
            guard !current.precededByBlankLine,
                  let caption = current.caption,
                  case let .prose(priorLines) = prior.content
            else {
                continue
            }
            committed[index - 1] = DoctorBlock(
                id: prior.id,
                precededByBlankLine: prior.precededByBlankLine,
                caption: prior.caption,
                content: .prose(priorLines + [caption]),
            )
            committed[index] = DoctorBlock(
                id: current.id,
                precededByBlankLine: current.precededByBlankLine,
                caption: nil,
                content: current.content,
            )
        }
    }

    private mutating func flushCurrent() {
        guard let builder = current else {
            return
        }
        current = nil
        let content: DoctorBlock.Content
        let isEmpty: Bool
        switch builder.type {
        case .prose:
            content = .prose(builder.proseLines)
            isEmpty = builder.proseLines.isEmpty
        case .command:
            content = .command(builder.commandSteps)
            isEmpty = builder.commandSteps.isEmpty
        case .data:
            content = .data(builder.dataItems)
            isEmpty = builder.dataItems.isEmpty
        case .link:
            content = .link(builder.linkItems)
            isEmpty = builder.linkItems.isEmpty
        }
        guard !isEmpty else {
            return
        }
        committed.append(DoctorBlock(
            id: committed.count,
            precededByBlankLine: builder.precededByBlankLine,
            caption: builder.caption,
            content: content,
        ))
    }

    private mutating func processLine(_ line: String) {
        let isIndented = line.first == " " || line.first == "\t"
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !isIndented {
            processUnindented(trimmed)
            return
        }
        guard !trimmed.isEmpty else {
            return
        }
        processIndented(trimmed)
    }

    private mutating func processUnindented(_ trimmed: String) {
        if trimmed.isEmpty {
            flushCurrent()
            pendingCaption = nil
            specialUnindentedActive = false
            nextBlockFollowsBlankLine = true
            return
        }
        if trimmed.hasSuffix(":") {
            flushCurrent()
            pendingCaption = trimmed
            specialUnindentedActive = acceptsUnindentedItems(trimmed)
            // Captions can still contain `` `brew …` `` chips — keep the chip surface working under
            // the new block model.
            appendChips(from: trimmed, into: &inlineChips)
            return
        }
        if collectUnindentedDataItem(trimmed) {
            return
        }
        appendProseLine(trimmed)
    }

    private mutating func collectUnindentedDataItem(_ trimmed: String) -> Bool {
        guard specialUnindentedActive, looksLikeItem(trimmed), !containsLink(trimmed) else {
            return false
        }
        if current?.type != .data {
            flushCurrent()
            current = BlockBuilder(
                type: .data,
                caption: pendingCaption,
                precededByBlankLine: consumePendingBlankLine(),
            )
            pendingCaption = nil
        }
        current?.dataItems.append(trimmed)
        return true
    }

    private mutating func appendProseLine(_ trimmed: String) {
        // Any orphan pendingCaption was a colon intro whose block never materialized — drop it; the
        // raw body still carries it for the verbatim fallback.
        if pendingCaption != nil {
            pendingCaption = nil
            specialUnindentedActive = false
        }
        if current?.type != .prose {
            flushCurrent()
            current = BlockBuilder(
                type: .prose,
                caption: nil,
                precededByBlankLine: consumePendingBlankLine(),
            )
        }
        current?.proseLines.append(trimmed)
        appendChips(from: trimmed, into: &inlineChips)
    }

    private mutating func processIndented(_ trimmed: String) {
        if let caption = pendingCaption {
            flushCurrent()
            let type = decideBlockType(firstMember: trimmed, intro: caption)
            current = BlockBuilder(
                type: type,
                caption: caption,
                precededByBlankLine: consumePendingBlankLine(),
            )
            pendingCaption = nil
        } else if current == nil || current?.type == .prose, parseFixStep(trimmed) != nil {
            // Stray command sits under a `.prose` block (or no block yet) without a colon intro
            // (e.g. `check_git_status`'s `git stash`). Only fire here so it doesn't hijack lines that
            // belong to an existing data/command/link block — `pip3` under "tools exist at both paths:"
            // must stay in the data block, not split into commands.
            flushCurrent()
            current = BlockBuilder(
                type: .command,
                caption: nil,
                precededByBlankLine: consumePendingBlankLine(),
            )
        } else if current == nil {
            current = BlockBuilder(
                type: .prose,
                caption: nil,
                precededByBlankLine: consumePendingBlankLine(),
            )
        }
        appendToCurrent(trimmed)
    }

    private mutating func consumePendingBlankLine() -> Bool {
        let value = nextBlockFollowsBlankLine
        nextBlockFollowsBlankLine = false
        return value
    }

    private mutating func appendToCurrent(_ trimmed: String) {
        guard current != nil else {
            return
        }
        switch current!.type {
        case .prose:
            current?.proseLines.append(trimmed)
        case .command:
            if let step = parseFixStep(trimmed) {
                current?.commandSteps.append(step)
            }
        case .data:
            if !containsLink(trimmed), !isValueLine(trimmed) {
                current?.dataItems.append(trimmed)
            }
        case .link:
            if let url = firstURL(in: trimmed) {
                current?.linkItems.append(DoctorLink(url: url, role: linkRole(for: url)))
            }
        }
    }

    private func decideBlockType(firstMember: String, intro: String) -> DoctorBlockType {
        if dataNounCue(intro) {
            return .data
        }
        if parseFixStep(firstMember) != nil {
            return .command
        }
        if containsLink(firstMember) {
            return .link
        }
        return .data
    }
}

// MARK: - Severity

private func parseSeverity(body: String) -> DoctorSeverity {
    if body.contains("Unsupported configuration:") {
        return .unsupported
    }
    if let match = body.firstMatch(of: /This is a Tier (\d) configuration:/) {
        switch Int(match.1) {
        case 1:
            return .info
        case 2:
            return .caution
        case 3:
            return .danger
        default:
            return .caution
        }
    }
    return .caution
}

// MARK: - Command classifier

private let knownExecutables: Set<String> = [
    "brew", "git", "rm", "mkdir", "chown", "chmod", "cp", "mv", "ln",
    "xcode-select", "softwareupdate", "csrutil", "launchctl",
    "pip", "pip3", "python", "python3", "ruby", "bash", "zsh",
    "echo", "fish_add_path", "set",
]

private func parseFixStep(_ trimmed: String) -> DoctorFixStep? {
    var tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    let needsAdmin = tokens.first == "sudo"
    if needsAdmin {
        tokens.removeFirst()
    }
    while let first = tokens.first, first == "env" || first.contains("=") {
        tokens.removeFirst()
    }
    guard let executable = tokens.first, knownExecutables.contains(executable) else {
        return nil
    }
    let arguments: [String]? = if executable == "brew", !needsAdmin {
        tokens.count > 1 ? Array(tokens.dropFirst()) : nil
    } else {
        nil
    }
    return DoctorFixStep(displayCommand: trimmed, arguments: arguments, needsAdmin: needsAdmin)
}

// MARK: - Backtick chips

private func appendChips(from line: String, into chips: inout [DoctorBacktickChip]) {
    let segments = line.components(separatedBy: "`")
    var index = 1
    while index < segments.count {
        let span = segments[index].trimmingCharacters(in: .whitespaces)
        if let chip = chip(from: span) {
            chips.append(chip)
        }
        index += 2
    }
}

private func chip(from span: String) -> DoctorBacktickChip? {
    let tokens = span.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard let first = tokens.first,
          knownExecutables.contains(first),
          tokens.count >= 2
    else {
        return nil
    }
    let arguments: [String]? = first == "brew" ? Array(tokens.dropFirst()) : nil
    return DoctorBacktickChip(displayCommand: span, arguments: arguments)
}

private func uniqueChips(_ chips: [DoctorBacktickChip]) -> [DoctorBacktickChip] {
    var seen: Set<String> = []
    var out: [DoctorBacktickChip] = []
    for chip in chips where seen.insert(chip.id).inserted {
        out.append(chip)
    }
    return out
}

// MARK: - Links

private let urlDetector: NSDataDetector? = try? NSDataDetector(
    types: NSTextCheckingResult.CheckingType.link.rawValue,
)

private func containsLink(_ line: String) -> Bool {
    guard let detector = urlDetector else {
        return false
    }
    let nsRange = NSRange(line.startIndex..., in: line)
    return detector.firstMatch(in: line, options: [], range: nsRange) != nil
}

private func firstURL(in line: String) -> URL? {
    guard let detector = urlDetector else {
        return nil
    }
    let nsRange = NSRange(line.startIndex..., in: line)
    return detector.firstMatch(in: line, options: [], range: nsRange)?.url
}

private func linkRole(for url: URL) -> DoctorLinkRole {
    let host = (url.host ?? "").replacingOccurrences(of: "www.", with: "")
    switch host {
    case "developer.apple.com", "macports.org":
        return .action
    default:
        return .reference
    }
}

// MARK: - Data-noun guard

private func dataNounCue(_ trimmedIntro: String) -> Bool {
    let lower = trimmedIntro.lowercased()
    let listNouns = [
        "tools", "formulae", "casks", "taps", "directories", "kegs",
        "places", "files", "paths",
    ]
    if listNouns.contains(where: { lower.contains($0) }) {
        return true
    }
    let phrases = [
        "the same name as",
        "not readable:",
        "on these:",
        "out of the way:",
    ]
    return phrases.contains { lower.contains($0) }
}

private func acceptsUnindentedItems(_ trimmedCue: String) -> Bool {
    let lower = trimmedCue.lowercased()
    return lower.hasSuffix("do not exist:") || lower.hasSuffix("not writable by your user:")
}

private func looksLikeItem(_ trimmed: String) -> Bool {
    if trimmed.hasPrefix("/") {
        return true
    }
    return !trimmed.contains(where: \.isWhitespace)
}

private func isValueLine(_ trimmed: String) -> Bool {
    trimmed.contains(" = ") || trimmed.contains(": ")
}

// MARK: - Section classifier

private func classifySection(title: String, body: String) -> DoctorSection {
    let titleLower = title.lowercased()
    let combined = (title + " " + body).lowercased()
    if matchesAny(combined, xcodeAndCLTKeywords) {
        return .xcodeAndCLT
    }
    if matchesAny(combined, environmentAndPathKeywords) {
        return .environmentAndPath
    }
    if titleLower.contains("cask") {
        return .casks
    }
    if matchesAny(combined, tapsAndGitKeywords) {
        return .tapsAndGit
    }
    if matchesAny(combined, strayFilesKeywords) {
        return .strayFiles
    }
    return .systemAndFormulae
}

private func matchesAny(_ haystack: String, _ keywords: [String]) -> Bool {
    keywords.contains { haystack.contains($0) }
}

private let xcodeAndCLTKeywords: [String] = [
    "xcode",
    "command line tools",
    "developer tools",
    "broken sdk",
    "supported sdk",
    " clt ",
    "clt installed",
]

private let environmentAndPathKeywords: [String] = [
    "your path",
    "in your path",
    "shell profile",
    "shell rc",
    "tmpdir",
    "non-prefixed",
    "non_prefixed",
    "not writable by your user",
    "directories do not exist",
]

private let tapsAndGitKeywords: [String] = [
    "tap ",
    "untap",
    "taps:",
    "git origin",
    "origin remote",
    "uncommitted",
    "homebrew git",
    "git config",
]

private let strayFilesKeywords: [String] = [
    "stray",
    "unbrewed",
    "unexpected ",
    "gettext",
    "iconv",
    "framework",
    "header files",
    "static librar",
    "broken symlinks",
    "files exist",
]
