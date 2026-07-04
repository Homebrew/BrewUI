//
//  ConfigViewModel.swift
//  BrewFeatureConfig
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
final class ConfigViewModel {
    @ObservationIgnored private let repository: any ConfigRepository
    @ObservationIgnored private let envFileRepository: any EnvFileRepository
    @ObservationIgnored private let processEnvironment: [String: String]

    /// Pending edits. Reset to the loaded file after a successful save / revert, and auto-synced when
    /// the underlying `brew.env` changes externally and the user hasn't started editing.
    private(set) var draft: BrewEnvFile = .init()

    /// When the user tries to add a custom row whose key is classified as dangerous, the row sits here
    /// until they explicitly confirm. The view renders a confirmation banner driven by this value.
    private(set) var pendingDangerousCustomRow: PendingCustomRow?

    init(
        repository: any ConfigRepository,
        envFileRepository: any EnvFileRepository,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
    ) {
        self.repository = repository
        self.envFileRepository = envFileRepository
        self.processEnvironment = processEnvironment
        // Seed the draft from the cached state if available so the editor renders the right initial
        // values immediately — important when switching back to the Configuration tab during a session.
        if case let .loaded(file) = envFileRepository.state {
            draft = file
        }
    }

    /// Mirrors the cached `brew config` snapshot owned by the repository — single source of truth across
    /// tab switches.
    var state: LoadState<BrewConfigSnapshot, any Error> {
        repository.state
    }

    /// Mirrors the cached `brew.env` state owned by the repository.
    var envFileState: LoadState<BrewEnvFile, any Error> {
        envFileRepository.state
    }

    /// Combined load state the Configuration page renders. Both halves need to be loaded for the page
    /// to show real content; `.failed` collapses either side's failure into a user-facing message so
    /// `AsyncContentView` can render the standard error chrome with a Retry affordance.
    var pageState: LoadState<ConfigPagePayload, String> {
        switch (state, envFileState) {
        case let (.loaded(snapshot), .loaded(envFile)):
            .loaded(ConfigPagePayload(snapshot: snapshot, envFile: envFile))
        case let (.failed(error), _):
            .failed(userMessage(for: error))
        case let (_, .failed(error)):
            .failed(userMessage(for: error))
        default:
            .loading
        }
    }

    /// Cache-first: subsequent appearances of the Configuration view hit the cached snapshot and don't
    /// trigger a re-fetch. The composition root (or scene-phase observer) calls `refresh()` to
    /// re-validate.
    func load() async {
        async let configLoad: Void = repository.load(forceRefresh: false)
        async let envFileLoad: Void = envFileRepository.load(forceRefresh: false)
        _ = await (configLoad, envFileLoad)
        syncDraftIfClean()
    }

    /// Forces a silent re-fetch. The repositories keep the existing `.loaded` value visible while the
    /// network/disk work runs, so the editor doesn't flash a loading state. After the env file finishes,
    /// the draft is auto-synced unless the user has pending edits.
    func refresh() async {
        async let configLoad: Void = repository.load(forceRefresh: true)
        async let envFileLoad: Void = envFileRepository.load(forceRefresh: true)
        _ = await (configLoad, envFileLoad)
        syncDraftIfClean()
    }

    /// Toggle binding source. Anything other than `"1"` is off.
    func isToggleOn(forKey key: String) -> Bool {
        draft.value(forKey: key) == "1"
    }

    /// String/integer binding source. `""` when unset so `TextField` bindings stay non-optional.
    func textValue(forKey key: String) -> String {
        draft.value(forKey: key) ?? ""
    }

    /// Advisory for the current `HOMEBREW_CASK_OPTS` draft value — `nil` when the value is empty or
    /// every token is recognised and safe. The view renders this beneath the field so the user can see
    /// "you pasted `--no-quarantine`, here's what that means" without us having to block the save.
    func caskOptsAdvisory() -> CaskOptsAdvisory? {
        let raw = draft.value(forKey: "HOMEBREW_CASK_OPTS") ?? ""
        guard !raw.isEmpty else {
            return nil
        }
        let advisory = CaskOpts.advisory(for: raw)
        return advisory.isClean ? nil : advisory
    }

    /// Called by the view on `envFileState` changes. When the underlying file changes externally and
    /// the user hasn't started editing, mirror the new content into the draft so the editor stays in
    /// sync. When there are pending edits, leave the draft alone.
    func envFileStateDidChange() {
        syncDraftIfClean()
    }

    private func syncDraftIfClean() {
        guard let file = envFileState.value else {
            return
        }
        draft = file
    }

    /// Maps any repository error to the user-facing copy shown in the AsyncContentView's error state.
    func userMessage(for error: any Error) -> String {
        if case let BrewCommandError.failed(_, stderr) = error {
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return String(
            localized: "Couldn't read the Homebrew configuration.",
            comment: "Configuration tab, generic load failure",
        )
    }

    // The read-only Configuration card surface (`sections`, `copyReport`, `errorMessage`, etc.) lives in
    // `ConfigViewModel+Sections.swift`. The Environment editor row helpers (`envRows`,
    // `advancedEnvRows`) live in the extension below.
}

// MARK: - Editor rows

extension ConfigViewModel {
    /// Rows the always-visible editor renders, in display order: the everyday allowlist,
    /// install-time read-only, then any custom rows present in the draft. Advanced allowlist rows
    /// (the ones that weaken default safety) are excluded — they live behind the Advanced
    /// disclosure and come from ``advancedEnvRows(envFile:)``. Takes the loaded `brew.env` so
    /// callers (typically `AsyncContentView`) can pass placeholder content for the redacted
    /// loading state.
    func envRows(envFile: BrewEnvFile) -> [EnvRowItem] {
        var rows: [EnvRowItem] = []
        var emitted: Set<String> = []

        for descriptor in EnvKeyCatalogue.editable where !descriptor.isAdvanced {
            rows.append(row(for: descriptor.key, descriptor: descriptor, envFile: envFile))
            emitted.insert(descriptor.key)
        }

        // Install-time rows: surface a value only if `brew config` reported one.
        for key in EnvKeyCatalogue.installTimeOnly.sorted() {
            rows.append(installTimeRow(forKey: key))
            emitted.insert(key)
        }

        // Reserve the advanced keys so a set value on disk doesn't reappear here as a custom row —
        // they belong to ``advancedEnvRows`` instead.
        for descriptor in EnvKeyCatalogue.editable where descriptor.isAdvanced {
            emitted.insert(descriptor.key)
        }

        // Custom rows already in the draft.
        for line in draft.lines {
            if case let .entry(key, _, _) = line, !emitted.contains(key), key.hasPrefix("HOMEBREW_") {
                rows.append(customRow(forKey: key))
                emitted.insert(key)
            }
        }

        return rows
    }

    /// Rows that live behind the Advanced disclosure: curated keys that weaken default brew
    /// safety. Same row shape as ``envRows(envFile:)`` so the view renders them with the shared
    /// row component.
    func advancedEnvRows(envFile: BrewEnvFile) -> [EnvRowItem] {
        EnvKeyCatalogue.editable
            .filter(\.isAdvanced)
            .map { row(for: $0.key, descriptor: $0, envFile: envFile) }
    }

    private func isShellOverridden(key: String) -> Bool {
        processEnvironment[key] != nil
    }

    private func row(for key: String, descriptor: EnvKeyDescriptor, envFile: BrewEnvFile) -> EnvRowItem {
        if let shellValue = processEnvironment[key] {
            return EnvRowItem(
                id: key,
                key: key,
                value: shellValue,
                provenance: .shell,
                status: .readOnlyShellOverridden(rcHint: shellRcHint()),
                descriptor: descriptor,
            )
        }
        let draftValue = draft.value(forKey: key)
        // Provenance: present in the on-disk file = `.envFile`; present in draft only = `.envFile` too
        // (user has staged an edit); nothing anywhere = `.defaultValue`.
        let provenance: EnvRowProvenance =
            envFile.value(forKey: key) != nil || draftValue != nil
                ? .envFile
                : .defaultValue
        return EnvRowItem(
            id: key,
            key: key,
            value: draftValue ?? "",
            provenance: provenance,
            status: .editable(descriptor.kind),
            descriptor: descriptor,
        )
    }

    private func installTimeRow(forKey key: String) -> EnvRowItem {
        let value = state.value?.entries.first(where: { $0.key == key })?.value
            ?? processEnvironment[key]
            ?? ""
        return EnvRowItem(
            id: key,
            key: key,
            value: value,
            provenance: .defaultValue,
            status: .readOnlyInstallTime,
            descriptor: nil,
        )
    }

    private func customRow(forKey key: String) -> EnvRowItem {
        if let shellValue = processEnvironment[key] {
            return EnvRowItem(
                id: key,
                key: key,
                value: shellValue,
                provenance: .shell,
                status: .readOnlyShellOverridden(rcHint: shellRcHint()),
                descriptor: nil,
            )
        }
        return EnvRowItem(
            id: key,
            key: key,
            value: draft.value(forKey: key) ?? "",
            provenance: .custom,
            status: .editable(.string),
            descriptor: nil,
        )
    }

    /// Best-effort hint about which shell rc the user would edit to remove an override. The editor
    /// surfaces this in the read-only badge copy so the user knows where to look next.
    private func shellRcHint() -> String {
        guard let shellPath = processEnvironment["SHELL"] else {
            return String(
                localized: "your shell config",
                comment: "Configuration tab, generic shell rc fallback",
            )
        }
        let shellName = (shellPath as NSString).lastPathComponent
        switch shellName {
        case "zsh":
            return "~/.zshrc"
        case "bash":
            return "~/.bash_profile"
        case "fish":
            return "~/.config/fish/config.fish"
        default:
            return String(
                localized: "your shell config",
                comment: "Configuration tab, generic shell rc fallback",
            )
        }
    }
}
