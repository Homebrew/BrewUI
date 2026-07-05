//
//  ConfigColumnsRoot.swift
//  BrewFeatureConfig
//

import BrewAppEnvironment
import BrewRepositoryInterfaces
import SwiftUI

/// Entry-point wrapper for the Configuration tab. Reads the config repository from the environment
/// (composed by the app's composition root) and hands it to the content view.
public struct ConfigColumnsRoot: View {
    @Environment(\.configRepository) private var configRepository

    public init() {}

    public var body: some View {
        ConfigView(repository: configRepository)
    }
}
