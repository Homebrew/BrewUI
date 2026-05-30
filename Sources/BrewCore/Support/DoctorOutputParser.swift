//
//  DoctorOutputParser.swift
//  BrewCore
//

import Foundation

/// Pure text→domain parser for `brew doctor` output. No dependencies, no isolation — unit-tested directly.
///
/// Classification follows `.ai/plans/DoctorParsing-Plan-Addendum.md`: a colon-terminated un-indented line
/// opens a *pending block*; the **first member** of that block decides whether the whole block is
/// commands, data, links, or prose. The executable allowlist is consulted *once* (for the first
/// member's command test), not per indented line — so a deprecated-tools list never gets scattered into
/// the commands rail. A `dataNounCue` guard forces data before the first-member command test in the
/// rare case the first item could read as a command (a deprecated formula named `git`, `python`, …).
///
/// Per-issue results: severity (tier callout / `Unsupported configuration:`), title, "What this means"
/// (prose residue), affected items (data blocks), fix sequences (command blocks grouped by intro / blank
/// line), inline backtick `brew …` chips, host-classified links, and a verbatim raw-body fallback.
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

/// What the parser is currently inside: a stretch of prose, a command run, a list of items, or a run of
/// link lines. Decided once at the start of each indented block by peeking at the first member.
private enum BlockMode {
    case prose
    case commands
    case data
    case links
}

private struct WarningBlockParser {
    let block: WarningBlock
    var fixSequences: [DoctorFixSequence] = []
    var currentSteps: [DoctorFixStep] = []
    var affectedItems: [String] = []
    var detailLines: [String] = []
    var inlineChips: [DoctorBacktickChip] = []
    var links: [DoctorLink] = []
    var mode: BlockMode = .prose
    /// `true` after a colon-terminated intro and before its first indented member arrives — that member
    /// decides the block's mode.
    var pendingBlock: Bool
    /// Last un-indented colon intro, kept so the first-member rule can consult the `dataNounCue` guard.
    var previousIntro: String
    /// `true` while a special intro (`do not exist:` / `not writable by your user:`) is allowing
    /// un-indented item lines to flow into Affected — brew prints those dir lists at column 0.
    var specialUnindentedActive: Bool

    init(block: WarningBlock) {
        self.block = block
        // The title can itself be the intro (e.g. `check_access_directories` puts it at column 0 of
        // the `Warning:` line). Seed the state machine from it.
        let titleIsIntro = block.title.hasSuffix(":")
        pendingBlock = titleIsIntro
        previousIntro = titleIsIntro ? block.title : ""
        specialUnindentedActive = titleIsIntro && acceptsUnindentedItems(block.title)
    }

    mutating func parse() -> DoctorIssue? {
        guard !block.title.isEmpty else {
            return nil
        }
        for line in block.bodyLines {
            processLine(line)
        }
        flushSequence()

        let rawBody = block.bodyLines.joined(separator: "\n")
        return DoctorIssue(
            title: block.title,
            severity: parseSeverity(body: rawBody),
            details: detailLines.joined(separator: " "),
            affectedItems: affectedItems,
            inlineChips: uniqueChips(inlineChips),
            fixSequences: fixSequences,
            links: uniqueLinks(links),
            rawBody: rawBody,
        )
    }

    private mutating func flushSequence() {
        guard !currentSteps.isEmpty else {
            return
        }
        fixSequences.append(DoctorFixSequence(id: fixSequences.count, steps: currentSteps))
        currentSteps = []
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

        if pendingBlock {
            pendingBlock = false
            mode = decideBlockMode(firstMember: trimmed)
        }
        handleIndented(trimmed)
    }

    private mutating func handleIndented(_ trimmed: String) {
        switch mode {
        case .commands, .prose:
            // .commands picks steps until the block ends; .prose picks up stray commands that sit
            // under period-ending prose (e.g. `git stash` / `rm -rf`). Both go through parseFixStep.
            if let step = parseFixStep(trimmed) {
                currentSteps.append(step)
            }
        case .data:
            appendDataLine(trimmed)
        case .links:
            appendLinks(from: trimmed, into: &links)
        }
    }

    private mutating func appendDataLine(_ trimmed: String) {
        guard !containsLink(trimmed) else {
            return
        }
        if isValueLine(trimmed) {
            detailLines.append(trimmed)
        } else {
            affectedItems.append(trimmed)
        }
    }

    private mutating func processUnindented(_ trimmed: String) {
        if trimmed.isEmpty {
            resetForBlankLine()
            return
        }
        if trimmed.hasSuffix(":") {
            beginIntro(trimmed)
            return
        }
        if collectUnindentedItem(trimmed) {
            return
        }
        finishAsProse(trimmed)
    }

    private mutating func resetForBlankLine() {
        flushSequence()
        mode = .prose
        pendingBlock = false
        specialUnindentedActive = false
    }

    private mutating func beginIntro(_ trimmed: String) {
        flushSequence()
        previousIntro = trimmed
        pendingBlock = true
        mode = .prose
        specialUnindentedActive = acceptsUnindentedItems(trimmed)
        detailLines.append(trimmed)
        appendLinks(from: trimmed, into: &links)
        appendChips(from: trimmed, into: &inlineChips)
    }

    private mutating func collectUnindentedItem(_ trimmed: String) -> Bool {
        guard specialUnindentedActive, looksLikeItem(trimmed), !containsLink(trimmed) else {
            return false
        }
        affectedItems.append(trimmed)
        return true
    }

    private mutating func finishAsProse(_ trimmed: String) {
        flushSequence()
        mode = .prose
        pendingBlock = false
        specialUnindentedActive = false
        if isLinkOnly(trimmed) {
            appendLinks(from: trimmed, into: &links)
            return
        }
        detailLines.append(trimmed)
        appendLinks(from: trimmed, into: &links)
        appendChips(from: trimmed, into: &inlineChips)
    }

    private func decideBlockMode(firstMember: String) -> BlockMode {
        // `dataNounCue` runs *before* the command test so a list whose first item could read as a
        // command (a deprecated formula named `git`/`python`/`node`, …) still classifies as data.
        if dataNounCue(previousIntro) {
            return .data
        }
        if parseFixStep(firstMember) != nil {
            return .commands
        }
        if containsLink(firstMember) {
            return .links
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

/// First non-`sudo`/non-`env`/non-`VAR=…` token must match this set to count as a command. With the
/// first-member rule, this list only decides whether the *first* member of a block opens a commands
/// block — it isn't consulted per line, so adding a missed verb only matters for blocks whose first
/// member is that verb. Add to the list as Homebrew adds checks that suggest new tools.
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

private func appendLinks(from line: String, into links: inout [DoctorLink]) {
    guard let detector = urlDetector else {
        return
    }
    let nsRange = NSRange(line.startIndex..., in: line)
    detector.enumerateMatches(in: line, options: [], range: nsRange) { match, _, _ in
        guard let url = match?.url else {
            return
        }
        links.append(DoctorLink(url: url, role: linkRole(for: url)))
    }
}

private func containsLink(_ line: String) -> Bool {
    guard let detector = urlDetector else {
        return false
    }
    let nsRange = NSRange(line.startIndex..., in: line)
    return detector.firstMatch(in: line, options: [], range: nsRange) != nil
}

private func isLinkOnly(_ trimmed: String) -> Bool {
    guard let detector = urlDetector else {
        return false
    }
    let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
    guard let match = detector.firstMatch(in: trimmed, options: [], range: nsRange),
          let urlRange = Range(match.range, in: trimmed)
    else {
        return false
    }
    let prefix = trimmed[trimmed.startIndex ..< urlRange.lowerBound].trimmingCharacters(in: .whitespaces)
    let suffix = trimmed[urlRange.upperBound ..< trimmed.endIndex].trimmingCharacters(in: .whitespaces)
    return prefix.isEmpty && (suffix.isEmpty || suffix == ".")
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

private func uniqueLinks(_ links: [DoctorLink]) -> [DoctorLink] {
    var seen: Set<URL> = []
    var out: [DoctorLink] = []
    for link in links where seen.insert(link.url).inserted {
        out.append(link)
    }
    return out
}

// MARK: - Data-noun guard

/// The only intro cue the addendum keeps: a hard guard that forces `.data` *before* the first-member
/// command test, so a list whose first item could read as a command (a deprecated formula named
/// `git`/`python`/`node`, …) still classifies as data. Keys on list-nouns (plural), not on bare
/// `following`, so the singular `following command:` correctly falls through to the content test.
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

/// `check_exist_directories` / `check_access_directories` print their dir lists un-indented; allow
/// those two intros to accept un-indented item lines until the next blank line.
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

/// Keeps key/value lines (`core.autocrlf = true`, `which resolves to: /path`, `Current developer
/// directory is: …`) out of Affected when the surrounding block has classified as data. They stay in
/// the prose residue instead — real item lines (paths, keg/formula names) don't contain `=` or `: `.
private func isValueLine(_ trimmed: String) -> Bool {
    trimmed.contains(" = ") || trimmed.contains(": ")
}
