//
//  DoctorOutputParser.swift
//  BrewCore
//

import Foundation

/// Pure text→domain parser for `brew doctor` output. No dependencies, no isolation — unit-tested directly.
///
/// Layered classifier (see `.ai/plans/DoctorParsing-Plan.md`):
///   * **Severity** comes from a tier callout (`This is a Tier N configuration:` / `Unsupported configuration:`).
///   * **Suggested fixes** are indented lines whose first post-`sudo`/`env` token is in the executable
///     allowlist; consecutive runs are grouped into one ordered sequence.
///   * **Affected items** are collected only under a recognized data-intro cue (`on these:`, `Unexpected …:`,
///     `following …:`, etc.) — never "every indented line", which would catch CLT URLs or value lines.
///   * **Inline chips** are backticked `brew …` references in prose, classified by the same allowlist.
///   * **Links** use `NSDataDetector`, split into action vs reference by host.
///   * **Raw body** is the verbatim fallback the detail pane shows beneath everything else.
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

private struct WarningBlockParser {
    let block: WarningBlock
    var fixSequences: [DoctorFixSequence] = []
    var currentSteps: [DoctorFixStep] = []
    var affectedItems: [String] = []
    var detailLines: [String] = []
    var inlineChips: [DoctorBacktickChip] = []
    var links: [DoctorLink] = []
    /// Some warnings (e.g. `check_access_directories`) put the data-intro cue in the title itself and
    /// start the body with the items. Arm from the title so those item lines are collected.
    var armedCue: Bool
    var armedAcceptsUnindented: Bool

    init(block: WarningBlock) {
        self.block = block
        let titleIsCue = isDataIntro(block.title)
        armedCue = titleIsCue
        armedAcceptsUnindented = titleIsCue && acceptsUnindentedItems(block.title)
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

        if trimmed.isEmpty {
            flushSequence()
            armedCue = false
            armedAcceptsUnindented = false
            return
        }

        if isIndented, let step = parseFixStep(trimmed) {
            currentSteps.append(step)
            return
        }
        flushSequence()

        if isDataIntro(trimmed) {
            armedCue = true
            armedAcceptsUnindented = acceptsUnindentedItems(trimmed)
            detailLines.append(trimmed)
            appendLinks(from: trimmed, into: &links)
            appendChips(from: trimmed, into: &inlineChips)
            return
        }

        let canCollectItem = armedCue
            && !containsLink(trimmed)
            && (isIndented || (armedAcceptsUnindented && looksLikeItem(trimmed)))
        if canCollectItem {
            affectedItems.append(trimmed)
            return
        }

        if !isIndented {
            armedCue = false
            armedAcceptsUnindented = false
        }

        if isLinkOnly(trimmed) {
            appendLinks(from: trimmed, into: &links)
            return
        }

        detailLines.append(trimmed)
        appendLinks(from: trimmed, into: &links)
        appendChips(from: trimmed, into: &inlineChips)
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

/// First non-`sudo`/non-`env`/non-`VAR=…` token must match this set to count as a command. Maintain this
/// list as Homebrew adds checks that recommend new tools — anything missed falls through to the
/// "What this means" residue rather than the Suggested-fix rail.
private let knownExecutables: Set<String> = [
    "brew", "git", "rm", "mkdir", "chown", "chmod", "cp", "mv", "ln",
    "xcode-select", "softwareupdate", "csrutil", "launchctl",
    "pip", "pip3", "python", "python3", "ruby", "bash", "zsh",
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
    // Backticked spans sit at odd indices once split on the backtick delimiter.
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
        // `brew` by itself or non-executable spans (`.gitconfig`, `$HOMEBREW_TEMP`) stay as inline code.
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

// MARK: - Data-intro cues

/// `true` when a trimmed line introduces a list of items (paths / kegs / formula names). The match set
/// is closed and was derived from walking every heredoc in `diagnostic.rb`.
private func isDataIntro(_ trimmed: String) -> Bool {
    guard trimmed.hasSuffix(":") else {
        return false
    }
    let lower = trimmed.lowercased()
    if lower.contains("following ") {
        return true
    }
    if lower.hasPrefix("unexpected ") {
        return true
    }
    if lower.hasSuffix(" files:") {
        return true
    }
    if lower.contains("to migrate to ") {
        return true
    }
    let specificSuffixes = [
        "paths found:",
        "uncommitted files:",
        "in the following places:",
        "out of the way:",
        "on these:",
        "not readable:",
    ]
    return specificSuffixes.contains { lower.hasSuffix($0) }
}

/// `check_exist_directories` and `check_access_directories` print their dir lists un-indented. Allow
/// those two cues to accept un-indented item lines until the next blank line.
private func acceptsUnindentedItems(_ trimmedCue: String) -> Bool {
    let lower = trimmedCue.lowercased()
    return lower.hasSuffix("do not exist:") || lower.hasSuffix("not writable by your user:")
}

/// Conservative item shape so the un-indented exception doesn't swallow following prose.
private func looksLikeItem(_ trimmed: String) -> Bool {
    if trimmed.hasPrefix("/") {
        return true
    }
    return !trimmed.contains(where: \.isWhitespace)
}
