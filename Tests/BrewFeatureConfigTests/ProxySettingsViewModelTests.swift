//
//  ProxySettingsViewModelTests.swift
//  BrewFeatureConfigTests
//

import BrewCore
@testable import BrewFeatureConfig
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct ProxySettingsViewModelTests {
    private static let manualHTTP = BrewProxySettings(
        mode: .manual,
        type: .http,
        host: "127.0.0.1",
        port: "7890",
    )

    @Test func `load populates the draft from the store`() {
        let store = StubUserBrewEnvironmentStore(settings: Self.manualHTTP)
        let viewModel = ProxySettingsViewModel(
            store: store,
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )

        viewModel.load()

        #expect(viewModel.draft.host == "127.0.0.1")
        #expect(viewModel.draft.port == "7890")
        #expect(viewModel.draft == viewModel.saved)
        #expect(!viewModel.isDirty)
        #expect(!viewModel.canSave)
        #expect(viewModel.isManualConfigurationEnabled)
    }

    @Test func `editing marks the draft dirty and enables save`() {
        let store = StubUserBrewEnvironmentStore()
        let viewModel = ProxySettingsViewModel(
            store: store,
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.load()

        viewModel.draft = Self.manualHTTP

        #expect(viewModel.isDirty)
        #expect(viewModel.canSave)
    }

    @Test func `invalid port disables save and produces a field message`() {
        let store = StubUserBrewEnvironmentStore()
        let viewModel = ProxySettingsViewModel(
            store: store,
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.load()

        viewModel.draft = BrewProxySettings(mode: .manual, host: "127.0.0.1", port: "abc")

        #expect(!viewModel.canSave)
        #expect(viewModel.validationMessage(for: .port) != nil)
        #expect(viewModel.validationMessage(for: .host) == nil)
    }

    @Test func `no-proxy mode hides the manual form and needs no host`() {
        let store = StubUserBrewEnvironmentStore()
        let viewModel = ProxySettingsViewModel(
            store: store,
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.load()

        viewModel.draft.mode = .none

        #expect(!viewModel.isManualConfigurationEnabled)
        #expect(viewModel.validationMessage(for: .host) == nil)
    }

    @Test func `removal saves despite an invalid hidden draft`() async {
        let store = StubUserBrewEnvironmentStore(settings: Self.manualHTTP)
        let viewModel = ProxySettingsViewModel(
            store: store,
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.load()
        viewModel.draft.host = "invalid\nvalue"
        viewModel.draft.mode = .none

        await viewModel.save()

        #expect(store.savedSettings == [viewModel.draft])
    }

    @Test(arguments: BrewProxySettings.Field.allCases)
    func `removal hides validation messages`(field: BrewProxySettings.Field) {
        let viewModel = ProxySettingsViewModel(
            store: StubUserBrewEnvironmentStore(),
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.draft[field] = "invalid\nvalue"

        #expect(viewModel.validationMessage(for: field) == nil)
    }

    @Test func `discard restores the saved values`() {
        let store = StubUserBrewEnvironmentStore(settings: Self.manualHTTP)
        let viewModel = ProxySettingsViewModel(
            store: store,
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.load()
        viewModel.draft.host = "edited"

        viewModel.discardChanges()

        #expect(viewModel.draft == viewModel.saved)
        #expect(viewModel.draft.host == "127.0.0.1")
    }

    @Test func `save writes the store and revalidates the config snapshot`() async {
        let store = StubUserBrewEnvironmentStore()
        let config = StubConfigRepository(snapshot: BrewConfigSnapshot(entries: []))
        let viewModel = ProxySettingsViewModel(store: store, configRepository: config)
        viewModel.load()
        viewModel.draft = BrewProxySettings(
            mode: .manual,
            type: .socks,
            host: "127.0.0.1",
            port: "1080",
        )

        await viewModel.save()

        #expect(store.savedSettings == [viewModel.draft])
        #expect(viewModel.didSaveSuccessfully)
        #expect(viewModel.saveErrorMessage == nil)
        #expect(!viewModel.isDirty)
        #expect(config.invalidateCount == 1)
    }

    @Test func `save failures keep the draft and surface a message`() async {
        let viewModel = ProxySettingsViewModel(
            store: FailOnSaveStore(),
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.load()
        viewModel.draft = Self.manualHTTP

        await viewModel.save()

        #expect(viewModel.saveErrorMessage != nil)
        #expect(!viewModel.didSaveSuccessfully)
        #expect(viewModel.draft.host == "127.0.0.1")
    }

    @Test func `newlines show a field error`() {
        let viewModel = ProxySettingsViewModel(
            store: StubUserBrewEnvironmentStore(),
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.draft = BrewProxySettings(
            mode: .manual,
            host: "127.0.0.1",
            port: "1",
            noProxy: "a\nb",
        )

        #expect(viewModel.validationMessage(for: .noProxy) != nil)
    }

    @Test func `authentication requires a login`() {
        let viewModel = ProxySettingsViewModel(
            store: StubUserBrewEnvironmentStore(),
            configRepository: StubConfigRepository(snapshot: BrewConfigSnapshot(entries: [])),
        )
        viewModel.draft = BrewProxySettings(
            mode: .manual,
            host: "127.0.0.1",
            port: "7890",
            usesAuthentication: true,
        )

        #expect(viewModel.validationMessage(for: .username) != nil)
        #expect(!viewModel.canSave)
    }
}

private final class FailOnSaveStore: UserBrewEnvironmentStoring, Sendable {
    func loadProxySettings() throws -> BrewProxySettings {
        .empty
    }

    func saveProxySettings(_: BrewProxySettings) throws {
        throw UserBrewEnvironmentError.unwritable(path: "brew.env")
    }
}
