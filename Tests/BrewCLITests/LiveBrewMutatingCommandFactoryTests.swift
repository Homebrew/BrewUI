import BrewCLI
import BrewCore
import Foundation
import Testing

struct LiveBrewMutatingCommandFactoryTests {
    @Test func `formula bottle preference affects formula commands only`() throws {
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: BrewCommands.forceBottlePreferenceKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: BrewCommands.forceBottlePreferenceKey)
            } else {
                defaults.removeObject(forKey: BrewCommands.forceBottlePreferenceKey)
            }
        }
        defaults.set(true, forKey: BrewCommands.forceBottlePreferenceKey)
        let factory = LiveBrewMutatingCommandFactory()

        #expect((
            factory.installCommand(kind: .formula, name: "git").arguments,
            factory.upgradeCommand(kind: .formula, name: "git").arguments,
            factory.installCommand(kind: .cask, name: "docker").arguments,
            factory.bulkUpgradeCommand(selection: .casks).arguments
        ) == (
            ["install", "--formula", "--force-bottle", "git"],
            ["upgrade", "--formula", "--force-bottle", "git"],
            ["install", "--cask", "docker"],
            ["upgrade", "--cask"]
        ))
    }
}
