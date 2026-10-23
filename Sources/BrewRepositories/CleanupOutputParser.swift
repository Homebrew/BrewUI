//
//  CleanupOutputParser.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// Pure text→domain parser for `brew cleanup --dry-run` output. No dependencies, no isolation — unit-tested
/// directly.
///
/// Homebrew has no JSON form of this output, so the parser reads only the line shapes `cleanup.rb` prints
/// and ignores everything else: an unfamiliar line is left to the raw output and the console rather than
/// guessed at.
public enum CleanupOutputParser {
    public static func parse(_ output: String, pruneAll: Bool) -> CleanupReport {
        var unneededFormulae: [String] = []
        var removals: [CleanupRemoval] = []
        var reclaimableSpace: String?
        var isReadingFormulae = false

        for rawLine in ANSIParser.plainText(output).components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if isReadingFormulae {
                if isFormulaName(line) {
                    unneededFormulae.append(line)
                    continue
                }
                isReadingFormulae = false
            }

            if line.hasPrefix(autoremoveHeaderPrefix) {
                isReadingFormulae = true
            } else if let removal = removal(in: line) {
                removals.append(removal)
            } else if let total = total(in: line) {
                reclaimableSpace = total
            }
        }

        return CleanupReport(
            pruneAll: pruneAll,
            unneededFormulae: unneededFormulae,
            removals: removals,
            reclaimableSpace: reclaimableSpace,
            rawOutput: output,
        )
    }

    /// `==> Would autoremove 2 unneeded formulae:`, followed by one full formula name per line.
    private static let autoremoveHeaderPrefix = "==> Would autoremove "

    private static let filePrefix = "Would remove: "
    private static let brokenLinkPrefix = "Would remove (broken link): "
    private static let emptyDirectoryPrefix = "Would remove (empty directory): "

    private static let totalPrefix = "==> This operation would free approximately "
    private static let totalSuffix = " of disk space."

    /// Full names such as `libyaml` or `homebrew/core/m4`, so a following line of prose ends the list.
    private static func isFormulaName(_ line: String) -> Bool {
        !line.isEmpty && line.unicodeScalars.allSatisfy(formulaNameCharacters.contains)
    }

    private static let formulaNameCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@+._/-"))

    private static func removal(in line: String) -> CleanupRemoval? {
        if line.hasPrefix(brokenLinkPrefix) {
            return CleanupRemoval(path: String(line.dropFirst(brokenLinkPrefix.count)), kind: .brokenLink)
        }
        if line.hasPrefix(emptyDirectoryPrefix) {
            return CleanupRemoval(path: String(line.dropFirst(emptyDirectoryPrefix.count)), kind: .emptyDirectory)
        }
        guard line.hasPrefix(filePrefix) else {
            return nil
        }
        let remainder = line.dropFirst(filePrefix.count)
        // `Would remove: <path> (<size>)`: the size is the last parenthesised group, so a path that
        // itself contains parentheses survives intact.
        guard remainder.hasSuffix(")"), let open = remainder.range(of: " (", options: .backwards) else {
            return CleanupRemoval(path: String(remainder), kind: .file)
        }
        return CleanupRemoval(
            path: String(remainder[..<open.lowerBound]),
            kind: .file,
            size: String(remainder[open.upperBound ..< remainder.index(before: remainder.endIndex)]),
        )
    }

    private static func total(in line: String) -> String? {
        guard line.hasPrefix(totalPrefix), line.hasSuffix(totalSuffix) else {
            return nil
        }
        return String(line.dropFirst(totalPrefix.count).dropLast(totalSuffix.count))
    }
}
