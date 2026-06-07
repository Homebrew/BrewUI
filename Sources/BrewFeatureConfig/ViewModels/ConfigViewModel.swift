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

    /// Drives the loading / loaded / failed chrome. Carries the underlying `Error` so this view model
    /// can map it to user-facing copy (`CONVENTIONS.md` — Loadable UI state).
    private(set) var state: LoadState<BrewConfigSnapshot, any Error> = .loading

    /// `brew.env` load state. A missing file isn't an error — the repository returns an empty file.
    private(set) var envFileState: LoadState<BrewEnvFile, any Error> = .loading

    /// Pending edits. Reset to the loaded file after a successful save / revert.
    private(set) var draft: BrewEnvFile = .init()

    /// Save-side error surfaced inline so the editor's main load state can stay `.loaded`.
    private(set) var saveError: String?

    init(
        repository: any ConfigRepository,
        envFileRepository: any EnvFileRepository,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
    ) {
        self.repository = repository
        self.envFileRepository = envFileRepository
        self.processEnvironment = processEnvironment
    }

    func load() async {
        state = .loading
        envFileState = .loading
        saveError = nil
        async let configCall: BrewConfigSnapshot = repository.loadConfig()
        async let envFileCall: BrewEnvFile = envFileRepository.loadEnvFile()

        do {
            state = try await .loaded(configCall)
        } catch {
            state = .failed(error)
        }

        do {
            let file = try await envFileCall
            envFileState = .loaded(file)
            draft = file
        } catch {
            envFileState = .failed(error)
            draft = BrewEnvFile()
        }
    }

    func refresh() async {
        await load()
    }

    // MARK: - Editing

    var isDirty: Bool {
        guard case let .loaded(loaded) = envFileState else {
            return false
        }
        return draft != loaded
    }

    /// Sets `key` to `value` in the pending draft. No-op when the row is read-only (shell-overridden or
    /// install-time) — the editor wires these as disabled, but the VM enforces it too as a safety net.
    func setValue(forKey key: String, to value: String) {
        guard !isShellOverridden(key: key), !EnvKeyCatalogue.isInstallTimeOnly(key) else {
            return
        }
        draft = draft.setting(key, value: value)
    }

    /// Removes a row from the draft. Used for toggling allowlist booleans off and for deleting custom rows.
    func removeRow(forKey key: String) {
        guard !isShellOverridden(key: key), !EnvKeyCatalogue.isInstallTimeOnly(key) else {
            return
        }
        draft = draft.removing(key: key)
    }

    /// Adds a custom `HOMEBREW_*` row. Rejects keys without the prefix and keys already covered by the
    /// curated allowlist or the install-time set (those should be set via their typed row instead).
    @discardableResult
    func addCustomRow(key: String, value: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard trimmedKey.hasPrefix("HOMEBREW_"), trimmedKey.count > "HOMEBREW_".count else {
            return false
        }
        guard EnvKeyCatalogue.descriptor(forKey: trimmedKey) == nil else {
            return false
        }
        guard !EnvKeyCatalogue.isInstallTimeOnly(trimmedKey) else {
            return false
        }
        draft = draft.setting(trimmedKey, value: value)
        return true
    }

    /// Toggle binding sink. `"1"` is the on-disk truthy value; off removes the entry entirely so it
    /// stops shadowing the default once persisted.
    func setToggle(forKey key: String, on: Bool) {
        if on {
            setValue(forKey: key, to: "1")
        } else {
            removeRow(forKey: key)
        }
    }

    /// String/secret binding sink. Empty input removes the row so the user can clear a value without
    /// reaching for the row-delete affordance.
    func setString(forKey key: String, to value: String) {
        if value.isEmpty {
            removeRow(forKey: key)
        } else {
            setValue(forKey: key, to: value)
        }
    }

    /// Integer binding sink. Strips non-digits so paste-from-`brew config` ("12 jobs") still works,
    /// clamps to the descriptor's range, and removes the row when the input has no digits at all.
    func setInteger(forKey key: String, rawText: String, minimum: Int, maximum: Int) {
        let digits = rawText.filter(\.isNumber)
        guard !digits.isEmpty else {
            removeRow(forKey: key)
            return
        }
        guard let parsed = Int(digits) else {
            return
        }
        let clamped = max(minimum, min(maximum, parsed))
        setValue(forKey: key, to: String(clamped))
    }

    /// Toggle binding source. Anything other than `"1"` is off.
    func isToggleOn(forKey key: String) -> Bool {
        draft.value(forKey: key) == "1"
    }

    /// String/integer binding source. `""` when unset so `TextField` bindings stay non-optional.
    func textValue(forKey key: String) -> String {
        draft.value(forKey: key) ?? ""
    }

    /// Discards pending edits, reverting `draft` to the loaded file.
    func revert() {
        guard case let .loaded(loaded) = envFileState else {
            return
        }
        draft = loaded
        saveError = nil
    }

    /// Persists `draft` via the repository. On success, the loaded state catches up so `isDirty` flips
    /// back to false. On failure, the draft is untouched and `saveError` carries the user-visible copy.
    func save() async {
        guard isDirty else {
            return
        }
        let snapshot = draft
        saveError = nil
        do {
            try await envFileRepository.save(snapshot)
            envFileState = .loaded(snapshot)
        } catch {
            saveError = String(
                localized: "Couldn't save brew.env: \(error.localizedDescription)",
                comment: "Configuration tab, save failure",
            )
        }
    }

    // MARK: - Editor rows

    /// Rows the editor renders, in display order: curated allowlist, install-time read-only set, then
    /// any custom rows already present in the draft. Returns `[]` while `brew.env` is still loading.
    var envRows: [EnvRowItem] {
        guard envFileState.value != nil else {
            return []
        }
        var rows: [EnvRowItem] = []
        var emitted: Set<String> = []

        for descriptor in EnvKeyCatalogue.editable {
            rows.append(row(for: descriptor.key, descriptor: descriptor))
            emitted.insert(descriptor.key)
        }

        // Install-time rows: surface a value only if `brew config` reported one.
        for key in EnvKeyCatalogue.installTimeOnly.sorted() {
            rows.append(installTimeRow(forKey: key))
            emitted.insert(key)
        }

        // Custom rows already in the draft.
        for line in draft.lines {
            if case let .entry(key, _) = line, !emitted.contains(key), key.hasPrefix("HOMEBREW_") {
                rows.append(customRow(forKey: key))
                emitted.insert(key)
            }
        }

        return rows
    }

    private func row(for key: String, descriptor: EnvKeyDescriptor) -> EnvRowItem {
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
        return EnvRowItem(
            id: key,
            key: key,
            value: draftValue ?? "",
            provenance: draftValue == nil ? .defaultValue : .envFile,
            status: .editable(descriptor.kind),
            descriptor: descriptor,
        )
    }

    private func installTimeRow(forKey key: String) -> EnvRowItem {
        let value = state.value?.environment.first(where: { $0.key == key })?.value
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

    private func isShellOverridden(key: String) -> Bool {
        processEnvironment[key] != nil
    }

    /// Best-effort hint about which shell rc the user would edit to remove an override. The editor
    /// surfaces this in the read-only badge copy so the user knows where to look next.
    private func shellRcHint() -> String {
        guard let shellPath = processEnvironment["SHELL"] else {
            return String(localized: "your shell config", comment: "Configuration tab, generic shell rc fallback")
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
            return String(localized: "your shell config", comment: "Configuration tab, generic shell rc fallback")
        }
    }

    // MARK: - Presentation

    // The read-only Configuration card surface (`sections`, `copyReport`, `errorMessage`, etc.) lives in
    // `ConfigViewModel+Sections.swift` to keep this type focused on the editing model.
}
