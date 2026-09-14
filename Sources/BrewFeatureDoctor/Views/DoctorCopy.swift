//
//  DoctorCopy.swift
//  BrewFeatureDoctor
//

import Foundation

/// Doctor preamble translated from the English copy emitted by `brew doctor`.
enum DoctorCopy {
    private static let warningPreambleDefaultValue = "Please note that these warnings are just used to help the Homebrew maintainers " +
        "with debugging if you file an issue. If everything you use Homebrew for is working fine: " +
        "please don't worry or file an issue; just ignore this. Thanks!"

    static let warningPreamble = String(
        localized: "Doctor warning preamble",
        defaultValue: "\(warningPreambleDefaultValue)",
        comment: "Explanation shown above brew doctor warnings",
    )

    private static let localizedProseResources: [String: LocalizedStringResource] = [
        "A newer Command Line Tools release is available.": "A newer Command Line Tools release is available.",
        "Update them from Software Update in System Settings.": "Update them from Software Update in System Settings.",
        "If that doesn't show you any updates, run:": "If that doesn't show you any updates, run:",
        "Alternatively, manually download them from:": "Alternatively, manually download them from:",
        "Homebrew is currently ignoring formulae, casks and commands " +
            "from these taps because tap trust is required.": """
            Homebrew is currently ignoring formulae, casks and commands \
            from these taps because tap trust is required.
            """,
        "Homebrew is currently ignoring formulae, casks and commands": "Homebrew is currently ignoring formulae, casks and commands",
        "from these taps because tap trust is required.": "from these taps because tap trust is required.",
        "Untap them with:": "Untap them with:",
        "Trust specific formulae, casks and commands with:": "Trust specific formulae, casks and commands with:",
        "Whole-tap trust is broader and includes all current and future formulae, casks and commands " +
            "from the listed taps. Trust whole taps with:": """
            Whole-tap trust is broader and includes all current and future formulae, casks and commands \
            from the listed taps. Trust whole taps with:
            """,
        "Whole-tap trust is broader and includes all current and future formulae,": "Whole-tap trust is broader and includes all current and future formulae,",
        "casks and commands from the listed taps. Trust whole taps with:": "casks and commands from the listed taps. Trust whole taps with:",
        "For more information, see:": "For more information, see:",
        "The following taps are not trusted:": "The following taps are not trusted:",
        "Calling string comparison format for `depends_on macos:` is deprecated! Use `depends_on macos: :big_sur` " +
            "instead.": "Calling string comparison format for `depends_on macos:` is deprecated! Use `depends_on macos: :big_sur` \("instead.")",
        "This is a Tier 2 configuration:": "This is a Tier 2 configuration:",
        "You can report issues with Tier 2 configurations to Homebrew/* repositories!": "You can report issues with Tier 2 configurations to Homebrew/* repositories!",
        "Read the above document before opening any issues or PRs.": "Read the above document before opening any issues or PRs.",
    ]

    /// Localizes stable prose emitted by `brew doctor` while preserving unknown diagnostics verbatim.
    /// The latter is important because Homebrew can add new warnings independently of BrewUI.
    static func localized(_ text: String) -> String {
        if let resource = localizedProseResources[text] {
            return String(localized: resource)
        }
        return localizedDynamicMessage(text)
    }

    private static func localizedDynamicMessage(_ text: String) -> String {
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
