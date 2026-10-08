//
//  ConfigColumnsRoot.swift
//  BrewFeatureConfig
//

import BrewAppEnvironment
import BrewRepositoryInterfaces
import SwiftUI

/// Entry-point wrapper for the Configuration tab. Reads the config repository and user `brew.env`
/// store from the environment (composed by the app's composition root) and hands them to the content view.
public struct ConfigColumnsRoot: View {
    @Environment(\.configRepository) private var configRepository
    @Environment(\.userBrewEnvironmentStore) private var userBrewEnvironmentStore

    public init() {}

    public var body: some View {
        ConfigView(repository: configRepository, proxyStore: userBrewEnvironmentStore)
    }
}
