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

/// One `brew doctor` warning, kept as an ordered list of typed blocks so renderers can preserve
/// document order and the intro caption of each block.
///
/// Prior parsed shape flattened body content into `details` + `affectedItems` + `fixSequences` + `links`,
/// which orphaned each fix from its own paths/files when a single check produced multiple subjects
/// (notably `check_git_status`'s "one block per dirty repo"). The block model keeps each fix bound to
/// its own data; `inlineChips` and `rawBody` remain cross-cutting indices.
public struct DoctorIssue: Equatable, Sendable {
    /// `Warning:` summary line, with the prefix stripped.
    public var title: String
    /// Severity derived from a support-tier callout (`This is a Tier N configuration:` /
    /// `Unsupported configuration:`). Unflagged warnings default to ``DoctorSeverity/caution``.
    public var severity: DoctorSeverity
    /// Coarse grouping for the issues list, mapped from the warning's text. Title-keyword stand-in for
    /// the plan's `check_name` mapping.
    public var section: DoctorSection
    /// Ordered list of blocks as they appear in the raw output. Each block keeps the colon-terminated
    /// intro that introduced it as its `caption`, so renderers can label sections by what brew actually
    /// wrote (e.g. ``Remove them with `brew cleanup`:``). Empty for a title-only warning.
    public var blocks: [DoctorBlock]
    /// Inline backticked references found in prose (e.g. `` `brew cleanup` ``, `` `brew link` ``) —
    /// copyable chips that are never promoted into the runnable suggested fix.
    public var inlineChips: [DoctorBacktickChip]
    /// Verbatim body the parser consumed, for the always-present dark-mono "Raw output" fallback and
    /// the multi-group escape hatch.
    public var rawBody: String

    public init(
        title: String,
        severity: DoctorSeverity,
        section: DoctorSection,
        blocks: [DoctorBlock],
        inlineChips: [DoctorBacktickChip],
        rawBody: String,
    ) {
        self.title = title
        self.severity = severity
        self.section = section
        self.blocks = blocks
        self.inlineChips = inlineChips
        self.rawBody = rawBody
    }
}

/// Support-tier severity, mapped from `brew doctor`'s tier callouts.
public enum DoctorSeverity: String, Equatable, Sendable {
    case info
    case caution
    case danger
    case unsupported
}

/// One typed block in a ``DoctorIssue``'s body — keeps document order and the intro caption that
/// produced it.
public struct DoctorBlock: Equatable, Sendable, Identifiable {
    public let id: Int
    public let caption: String?
    public let content: Content

    public enum Content: Equatable, Sendable {
        /// Un-indented prose lines. No caption (prose lines that end in `:` are captions, not prose).
        case prose([String])
        /// Indented command lines, parsed via the executable allowlist.
        case command([DoctorFixStep])
        /// Indented list of concrete items (paths, keg/formula names) — collected only under a
        /// colon-introduced data block.
        case data([String])
        /// Indented list of URLs — collected only under a colon-introduced link block.
        case link([DoctorLink])
    }

    public init(id: Int, caption: String?, content: Content) {
        self.id = id
        self.caption = caption
        self.content = content
    }

    public var type: DoctorBlockType {
        switch content {
        case .prose: .prose
        case .command: .command
        case .data: .data
        case .link: .link
        }
    }

    /// `true` iff this is a single non-admin `brew` command block we can submit through the command
    /// center. Multi-step command blocks and anything needing `sudo` are copy-only.
    public var isRunnable: Bool {
        guard case let .command(steps) = content, steps.count == 1, let step = steps.first else {
            return false
        }
        return step.arguments != nil && !step.needsAdmin
    }

    /// Joined command text suitable for clipboard "Copy all" — one step per line. Empty for non-command
    /// blocks.
    public var copyAllText: String {
        guard case let .command(steps) = content else {
            return ""
        }
        return steps.map(\.displayCommand).joined(separator: "\n")
    }
}

public enum DoctorBlockType: String, Equatable, Sendable {
    case prose
    case command
    case data
    case link
}

/// One step inside a ``DoctorBlock``'s `.command` content — a single command line as `brew doctor` printed it.
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

/// A `brew …` reference parsed out of a backticked span inside prose. Render as a copyable chip; do not
/// promote into the runnable suggested fix (the indented commands are the runnable form).
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

/// A URL surfaced from a `.link` block, classified by what the user is meant to do with it.
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

public enum DoctorLinkRole: String, Equatable, Sendable {
    case action
    case reference
}

/// Coarse grouping for the issues list, modelled on the curated `check_name` → section map sketched
/// in `.ai/plans/DoctorParsing-Plan.md` §8. Since `brew doctor` output doesn't include check names, the
/// parser classifies by title/body keywords instead.
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
