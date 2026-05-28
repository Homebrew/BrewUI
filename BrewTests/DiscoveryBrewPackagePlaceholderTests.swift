@testable import Brew
import Foundation
import Testing

struct DiscoveryBrewPackagePlaceholderTests {
    @Test func `array placeholder has distinct ids`() {
        let placeholders = [DiscoveryBrewPackage].placeholder
        #expect(!placeholders.isEmpty)
        #expect(Set(placeholders.map(\.id)).count == placeholders.count)
    }

    @Test func `array placeholder mixes formulae and casks`() {
        let placeholders = [DiscoveryBrewPackage].placeholder
        #expect(placeholders.contains { $0.kind == .formula })
        #expect(placeholders.contains { $0.kind == .cask })
    }

    @Test func `element placeholder has realistic stub data`() {
        let placeholder = DiscoveryBrewPackage.placeholder
        #expect(!placeholder.name.isEmpty)
        #expect(!placeholder.description.isEmpty)
        #expect(!placeholder.latestVersion.isEmpty)
    }
}
