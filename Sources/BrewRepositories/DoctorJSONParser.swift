//
//  DoctorJSONParser.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// Maps `brew doctor --json` onto the domain model.
///
/// Structure brew states outright — the findings, their support tiers, the commands it considers safe to
/// offer — comes from the JSON rather than being inferred. Only the *shape* of each finding's free text is
/// left, and that goes to ``DoctorOutputParser/issue(title:body:severity:)``.
public enum DoctorJSONParser {
    /// Throws when `data` is not this command's JSON — which is how the repository detects a brew too old
    /// to know the switch, since that brew writes an error instead.
    public static func parse(_ data: Data) throws -> [DoctorIssue] {
        let payload = try JSONDecoder().decode(DoctorJSON.self, from: data)
        return payload.findings.compactMap(issue(from:))
    }

    private static func issue(from finding: DoctorJSONFinding) -> DoctorIssue? {
        // brew wraps URLs in remediation text with underline codes, so escapes reach us inside JSON
        // string values.
        let printed = ANSIParser.plainText(printedForm(of: finding))
        let lines = printed.components(separatedBy: "\n")
        guard let title = lines.first?.trimmingCharacters(in: .whitespaces), !title.isEmpty else {
            return nil
        }
        let body = lines.dropFirst().joined(separator: "\n")
        guard var issue = DoctorOutputParser.issue(
            title: title,
            body: body,
            severity: severity(for: finding.tier),
        ) else {
            return nil
        }
        issue.blocks = restrictRunnableSteps(in: issue.blocks, to: finding.remediation?.commands ?? [])
        issue.blocks += metadataBlocks(for: finding, startingAt: issue.blocks.count, body: printed)
        return issue
    }

    /// What the CLI prints for this finding, rebuilt from the fields brew serialised it from — a mirror of
    /// `Finding#to_s` and `Remediation#to_s` in `Homebrew/diagnostic/finding.rb`.
    private static func printedForm(of finding: DoctorJSONFinding) -> String {
        let text = finding.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let remediation = printedRemediation(finding.remediation)
        guard !remediation.isEmpty else {
            return text
        }
        return "\(text)\n\(remediation)"
    }

    private static func printedRemediation(_ remediation: DoctorJSONRemediation?) -> String {
        guard let remediation else {
            return ""
        }
        let text = remediation.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }
        guard !remediation.commands.isEmpty else {
            return ""
        }
        return "You can solve this by running:\n  " + remediation.commands.joined(separator: "\n  ")
    }

    /// A step is only offered as a Run Fix if brew listed it under `remediation.commands`. The free text
    /// contains command lines brew deliberately kept out of that array, so those stay copy-only.
    private static func restrictRunnableSteps(
        in blocks: [DoctorBlock],
        to commands: [String],
    ) -> [DoctorBlock] {
        let sanctioned = Set(commands.map { ANSIParser.plainText($0).trimmingCharacters(in: .whitespaces) })
        return blocks.map { block in
            guard case let .command(steps) = block.content else {
                return block
            }
            let restricted = steps.map { step in
                sanctioned.contains(step.displayCommand)
                    ? step
                    : DoctorFixStep(
                        displayCommand: step.displayCommand,
                        arguments: nil,
                        needsAdmin: step.needsAdmin,
                    )
            }
            return DoctorBlock(
                id: block.id,
                precededByBlankLine: block.precededByBlankLine,
                caption: block.caption,
                content: .command(restricted),
            )
        }
    }

    /// `affects` and `links` are appended only where the body does not already say the same thing, so a
    /// finding whose text already lists its casks isn't shown them twice.
    private static func metadataBlocks(
        for finding: DoctorJSONFinding,
        startingAt nextID: Int,
        body: String,
    ) -> [DoctorBlock] {
        var blocks: [DoctorBlock] = []
        let unlisted = finding.affects.filter { !body.contains($0) }
        if !unlisted.isEmpty {
            blocks.append(DoctorBlock(
                id: nextID,
                precededByBlankLine: true,
                caption: "Affects:",
                content: .data(unlisted),
            ))
        }
        let links = finding.links
            .compactMap { URL(string: ANSIParser.plainText($0).trimmingCharacters(in: .whitespaces)) }
            .filter { !body.contains($0.absoluteString) }
        if !links.isEmpty {
            blocks.append(DoctorBlock(
                id: nextID + blocks.count,
                precededByBlankLine: true,
                caption: "More information:",
                content: .link(links.map { DoctorLink(url: $0, role: .reference) }),
            ))
        }
        return blocks
    }

    /// Support tier onto the app's severity, matching what the text path derives from brew's tier
    /// callouts. An unrecognised tier reads as the mildest rather than alarming the user over a value the
    /// app doesn't know.
    private static func severity(for tier: DoctorJSONTier) -> DoctorSeverity {
        switch tier {
        case .unsupported:
            .unsupported
        case let .numbered(number):
            number >= 3 ? .danger : .caution
        case .unknown:
            .caution
        }
    }
}
