//
//  DoctorCopy.swift
//  BrewFeatureDoctor
//

import Foundation

/// Doctor preamble translated from the English copy emitted by `brew doctor`.
enum DoctorCopy {
    static let warningPreamble = String(
        localized: "Doctor warning preamble",
        defaultValue: "Please note that these warnings are just used to help the Homebrew maintainers with debugging if you file an issue. If everything you use Homebrew for is working fine: please don't worry or file an issue; just ignore this. Thanks!",
        comment: "Explanation shown above brew doctor warnings",
    )

    /// Localizes stable prose emitted by `brew doctor` while preserving unknown diagnostics verbatim.
    /// The latter is important because Homebrew can add new warnings independently of BrewUI.
    static func localized(_ text: String) -> String {
        switch text {
        case "A newer Command Line Tools release is available.":
            return String(
                localized: "A newer Command Line Tools release is available.",
                comment: "Doctor warning title for an available Command Line Tools update",
            )
        case "Update them from Software Update in System Settings.":
            return String(
                localized: "Update them from Software Update in System Settings.",
                comment: "Doctor instructions for updating Command Line Tools",
            )
        case "If that doesn't show you any updates, run:":
            return String(
                localized: "If that doesn't show you any updates, run:",
                comment: "Doctor fallback instructions before update commands",
            )
        case "Alternatively, manually download them from:":
            return String(
                localized: "Alternatively, manually download them from:",
                comment: "Doctor fallback instructions before the Apple download link",
            )
        case "Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.":
            return String(
                localized: "Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.",
                comment: "Doctor explanation for untrusted taps",
            )
        case "Homebrew is currently ignoring formulae, casks and commands":
            return String(
                localized: "Homebrew is currently ignoring formulae, casks and commands",
                comment: "First line of doctor explanation for untrusted taps",
            )
        case "from these taps because tap trust is required.":
            return String(
                localized: "from these taps because tap trust is required.",
                comment: "Second line of doctor explanation for untrusted taps",
            )
        case "Untap them with:":
            return String(
                localized: "Untap them with:",
                comment: "Doctor caption before untap commands",
            )
        case "Trust specific formulae, casks and commands with:":
            return String(
                localized: "Trust specific formulae, casks and commands with:",
                comment: "Doctor caption before specific tap trust commands",
            )
        case "Whole-tap trust is broader and includes all current and future formulae, casks and commands from the listed taps. Trust whole taps with:":
            return String(
                localized: "Whole-tap trust is broader and includes all current and future formulae, casks and commands from the listed taps. Trust whole taps with:",
                comment: "Doctor explanation and caption for trusting whole taps",
            )
        case "Whole-tap trust is broader and includes all current and future formulae,":
            return String(
                localized: "Whole-tap trust is broader and includes all current and future formulae,",
                comment: "First line of doctor explanation for trusting whole taps",
            )
        case "casks and commands from the listed taps. Trust whole taps with:":
            return String(
                localized: "casks and commands from the listed taps. Trust whole taps with:",
                comment: "Second line of doctor explanation and caption for trusting whole taps",
            )
        case "For more information, see:":
            return String(
                localized: "For more information, see:",
                comment: "Doctor caption before documentation links",
            )
        case "The following taps are not trusted:":
            return String(
                localized: "The following taps are not trusted:",
                comment: "Doctor warning title for untrusted taps",
            )
        case "Calling string comparison format for `depends_on macos:` is deprecated! Use `depends_on macos: :big_sur` instead.":
            return String(
                localized: "Calling string comparison format for `depends_on macos:` is deprecated! Use `depends_on macos: :big_sur` instead.",
                comment: "Doctor warning about deprecated macOS dependency syntax",
            )
        case "This is a Tier 2 configuration:":
            return String(
                localized: "This is a Tier 2 configuration:",
                comment: "Doctor support tier caption",
            )
        case "You can report issues with Tier 2 configurations to Homebrew/* repositories!":
            return String(
                localized: "You can report issues with Tier 2 configurations to Homebrew/* repositories!",
                comment: "Doctor support tier guidance",
            )
        case "Read the above document before opening any issues or PRs.":
            return String(
                localized: "Read the above document before opening any issues or PRs.",
                comment: "Doctor support tier closing guidance",
            )
        default:
            let reportPrefix = "Please report this issue to the "
            let reportSuffix = " (not Homebrew/* repositories), or even better, submit a PR to fix it:"
            if text.hasPrefix(reportPrefix), text.hasSuffix(reportSuffix) {
                let target = text.dropFirst(reportPrefix.count).dropLast(reportSuffix.count)
                let format = String(
                    localized: "Please report this issue to the %@ (not Homebrew/* repositories), or even better, submit a PR to fix it:",
                    comment: "Doctor instruction for reporting a tap issue",
                )
                return format.replacingOccurrences(of: "%@", with: String(target))
            }
            let prefix = "You should download the Command Line Tools for Xcode "
            guard text.hasPrefix(prefix), text.hasSuffix(".") else {
                return text
            }
            let version = text.dropFirst(prefix.count).dropLast()
            let format = String(
                localized: "You should download the Command Line Tools for Xcode %@.",
                comment: "Doctor instructions naming the required Command Line Tools version",
            )
            return format.replacingOccurrences(of: "%@", with: String(version))
        }
    }
}
