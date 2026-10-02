//
//  ProxySettingsViewModel.swift
//  BrewFeatureConfig
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

/// Draft-and-save editor for the user `brew.env` proxy keys, shaped like a manual IDE proxy form.
///
/// Draft state stays here until Save so `brew config` and the copy report keep describing what
/// `brew` actually sees. Saving writes the user file and asks the config repository to revalidate.
@Observable
@MainActor
final class ProxySettingsViewModel {
    @ObservationIgnored private let store: any UserBrewEnvironmentStoring
    @ObservationIgnored private let configRepository: any ConfigRepository

    var draft = BrewProxySettings.empty
    private(set) var saved = BrewProxySettings.empty
    private(set) var isSaving = false
    private(set) var saveErrorMessage: String?
    private(set) var didSaveSuccessfully = false

    init(store: any UserBrewEnvironmentStoring, configRepository: any ConfigRepository) {
        self.store = store
        self.configRepository = configRepository
    }

    var isDirty: Bool {
        draft != saved
    }

    var canSave: Bool {
        isDirty && !isSaving && draft.validate().isEmpty
    }

    var isManualConfigurationEnabled: Bool {
        draft.mode == .manual
    }

    func load() {
        do {
            let settings = try store.loadProxySettings()
            saved = settings
            draft = settings
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = Self.message(for: error)
        }
    }

    func discardChanges() {
        draft = saved
        saveErrorMessage = nil
        didSaveSuccessfully = false
    }

    func save() async {
        guard canSave else { return }
        isSaving = true
        saveErrorMessage = nil
        didSaveSuccessfully = false
        defer { isSaving = false }
        do {
            try store.saveProxySettings(draft)
            saved = draft
            didSaveSuccessfully = true
            configRepository.invalidate()
            await configRepository.load(forceRefresh: true)
        } catch {
            saveErrorMessage = Self.message(for: error)
        }
    }

    /// Field-level copy for a draft value, or nil when the field is empty or valid.
    func validationMessage(for field: BrewProxySettings.Field) -> String? {
        guard draft.mode == .manual else {
            return nil
        }
        let value = draft[field]
        if value.contains("\n") || value.contains("\r") {
            return String(
                localized: "Remove line breaks from this value.",
                bundle: #bundle,
                comment: "Proxy settings: field contains a newline",
            )
        }
        switch field {
        case .host:
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return String(
                    localized: "Host name is required.",
                    bundle: #bundle,
                    comment: "Proxy settings: host is empty in manual mode",
                )
            }
            if draft.validate().contains(.invalidHost) {
                return String(
                    localized: "Use a host name or IP address without a URL scheme or path.",
                    bundle: #bundle,
                    comment: "Proxy settings: host contains invalid URL components",
                )
            }
        case .port:
            if !BrewProxySettings.isValidPort(value) {
                return String(
                    localized: "Use a port from 1 to 65535.",
                    bundle: #bundle,
                    comment: "Proxy settings: port is not a valid TCP port",
                )
            }
        case .username:
            if draft.usesAuthentication, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return String(
                    localized: "Login is required when proxy authentication is on.",
                    bundle: #bundle,
                    comment: "Proxy settings: username empty while authentication is enabled",
                )
            }
        case .noProxy, .password:
            return nil
        }
        return nil
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case UserBrewEnvironmentError.unreadable:
            String(
                localized: "Couldn’t read ~/.homebrew/brew.env.",
                bundle: #bundle,
                comment: "Proxy settings: user brew.env could not be read",
            )
        case UserBrewEnvironmentError.unwritable:
            String(
                localized: "Couldn’t write ~/.homebrew/brew.env.",
                bundle: #bundle,
                comment: "Proxy settings: user brew.env could not be written",
            )
        case UserBrewEnvironmentError.rejectedValue:
            String(
                localized: "That value can’t be saved to brew.env.",
                bundle: #bundle,
                comment: "Proxy settings: store refused the value",
            )
        default:
            String(
                localized: "Couldn’t save the proxy settings.",
                bundle: #bundle,
                comment: "Proxy settings: generic save failure",
            )
        }
    }
}
