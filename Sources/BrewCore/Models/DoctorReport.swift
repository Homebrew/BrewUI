//
//  DoctorReport.swift
//  BrewCore
//

import Foundation

/// Outcome of a `brew doctor` run, parsed into structured issues.
///
/// Actor-neutral domain value (no presentation). A report with no issues means a healthy system —
/// `brew doctor` printed "Your system is ready to brew." rather than any warnings.
public struct DoctorReport: Equatable, Sendable {
    public var issues: [DoctorIssue]

    public init(issues: [DoctorIssue]) {
        self.issues = issues
    }

    /// `true` when `brew doctor` surfaced no warnings.
    public var isHealthy: Bool {
        issues.isEmpty
    }
}

/// One `brew doctor` warning, sectioned for the detail pane.
///
/// The fields reflect the layered classifier described in `.ai/plans/DoctorParsing-Plan.md`: severity is
/// the support-tier signal, ``affectedItems`` is collected only under closed data-intro cues (not "every
/// indented line"), ``fixSequences`` groups consecutive indented commands into ordered runs, ``inlineChips``
/// surfaces backticked `brew …` references in prose without promoting them to primary fixes, and
/// ``rawBody`` is the verbatim fallback that's never wrong.
public struct DoctorIssue: Equatable, Sendable {
    /// `Warning:` summary line, with the prefix stripped.
    public var title: String
    /// Severity derived from a support-tier callout (`This is a Tier N configuration:` /
    /// `Unsupported configuration:`). Unflagged warnings default to ``DoctorSeverity/caution``.
    public var severity: DoctorSeverity
    /// Coarse grouping for the issues list, mapped from the warning's text. The plan's `check_name`
    /// mapping would be more precise; brew doctor doesn't print check names so this is a title-keyword
    /// stand-in (an explicit, revertable trade-off).
    public var section: DoctorSection
    /// "What this means" prose — everything that wasn't consumed as command, data line, link, or chip.
    public var details: String
    /// Concrete items the warning enumerates (unlinked kegs, offending paths, …). Anchored to recognized
    /// data-intro cue lines so stray values don't fall in.
    public var affectedItems: [String]
    /// Inline backticked references found in prose (e.g. `` `brew cleanup` ``, `` `brew link` ``) — copyable
    /// chips that are usually generic, not the runnable suggested fix.
    public var inlineChips: [DoctorBacktickChip]
    /// Suggested fixes parsed from indented command lines, grouped into ordered sequences (`rm` then
    /// `brew tap`; `mkdir` then `chown`; …). Empty when there is no runnable guidance.
    public var fixSequences: [DoctorFixSequence]
    /// URLs found in the body, split into action vs reference by host.
    public var links: [DoctorLink]
    /// Verbatim body the parser consumed, for a dark-mono "Raw output" fallback.
    public var rawBody: String

    public init(
        title: String,
        severity: DoctorSeverity,
        section: DoctorSection,
        details: String,
        affectedItems: [String],
        inlineChips: [DoctorBacktickChip],
        fixSequences: [DoctorFixSequence],
        links: [DoctorLink],
        rawBody: String,
    ) {
        self.title = title
        self.severity = severity
        self.section = section
        self.details = details
        self.affectedItems = affectedItems
        self.inlineChips = inlineChips
        self.fixSequences = fixSequences
        self.links = links
        self.rawBody = rawBody
    }
}

/// Coarse grouping for the issues list, modelled on the curated `check_name` → section map sketched
/// in `.ai/plans/DoctorParsing-Plan.md` §8. Since `brew doctor` output doesn't include check names, the
/// parser classifies by title/body keywords instead — accurate enough to organize the list but not as
/// precise as actually running each check individually would be.
public enum DoctorSection: String, CaseIterable, Equatable, Sendable, Identifiable {
    case xcodeAndCLT
    case environmentAndPath
    case casks
    case tapsAndGit
    case strayFiles
    case systemAndFormulae

    public var id: String {
        rawValue
    }

    /// Human-readable section heading.
    public var displayName: String {
        switch self {
        case .xcodeAndCLT: "Xcode & Command Line Tools"
        case .environmentAndPath: "Environment & PATH"
        case .casks: "Casks"
        case .tapsAndGit: "Taps & Git"
        case .strayFiles: "Stray Files"
        case .systemAndFormulae: "System & Formulae"
        }
    }
}

/// Support-tier severity, mapped from `brew doctor`'s tier callouts.
///
/// Presentation maps these to *system* semantic colors (info / caution / danger). Homebrew amber stays
/// reserved for the Homebrew warning glyph and progress UI — spending it on tiers dilutes the brand.
public enum DoctorSeverity: String, Equatable, Sendable {
    case info
    case caution
    case danger
    case unsupported
}

/// One step inside a ``DoctorFixSequence`` — a single command line as `brew doctor` printed it.
public struct DoctorFixStep: Equatable, Sendable {
    /// Verbatim command line (e.g. `"sudo chown -R me /opt/homebrew"`, `"brew link openssl@3"`).
    public var displayCommand: String
    /// `brew` argv with the leading `brew` dropped, when this step is a runnable brew invocation we can
    /// submit through the command center; `nil` for `sudo`/external/multi-tool steps.
    public var arguments: [String]?
    /// `true` when the line begins with `sudo` — render a "needs admin · runs in Terminal" note.
    public var needsAdmin: Bool

    public init(displayCommand: String, arguments: [String]?, needsAdmin: Bool) {
        self.displayCommand = displayCommand
        self.arguments = arguments
        self.needsAdmin = needsAdmin
    }
}

/// Ordered run of consecutive indented commands brew printed as one suggested fix (`rm` then `brew tap`,
/// `mkdir` then `chown`, `rm -rf` then `xcode-select --install`). One "Copy all" beats N loose buttons.
public struct DoctorFixSequence: Equatable, Sendable, Identifiable {
    public var id: Int
    public var steps: [DoctorFixStep]

    public init(id: Int, steps: [DoctorFixStep]) {
        self.id = id
        self.steps = steps
    }

    /// Joined command text suitable for clipboard / "Copy all" — one step per line.
    public var copyAllText: String {
        steps.map(\.displayCommand).joined(separator: "\n")
    }

    /// `true` iff this is a single non-admin `brew` step we can submit through the command center.
    /// Multi-step sequences and anything needing `sudo` are copy-only.
    public var isRunnable: Bool {
        guard steps.count == 1, let step = steps.first else {
            return false
        }
        return step.arguments != nil && !step.needsAdmin
    }
}

/// A `brew …` reference parsed out of a backticked span inside prose. Render as a copyable chip; do not
/// promote into the "Suggested fix" rail (the indented commands are the runnable form).
public struct DoctorBacktickChip: Equatable, Sendable, Identifiable {
    /// The text inside the backticks, e.g. `"brew cleanup"`.
    public var displayCommand: String
    /// `brew` argv (after dropping the leading `brew`) when this chip is a runnable `brew` invocation;
    /// `nil` for non-brew references (`xcode-select`, `.gitconfig`, environment variables).
    public var arguments: [String]?

    public var id: String {
        displayCommand
    }

    public init(displayCommand: String, arguments: [String]?) {
        self.displayCommand = displayCommand
        self.arguments = arguments
    }
}

/// A URL surfaced from a doctor warning, classified by what the user is meant to do with it.
public struct DoctorLink: Equatable, Sendable, Identifiable {
    public var url: URL
    public var role: DoctorLinkRole

    public var id: URL {
        url
    }

    public init(url: URL, role: DoctorLinkRole) {
        self.url = url
        self.role = role
    }
}

/// Whether a URL is something the user **does** (download, install) or something the user **reads**
/// (docs, troubleshooting, issue references).
public enum DoctorLinkRole: String, Equatable, Sendable {
    /// Primary affordance — downloads, alternative tools the user should grab.
    case action
    /// Muted/secondary affordance — documentation, issue references.
    case reference
}
