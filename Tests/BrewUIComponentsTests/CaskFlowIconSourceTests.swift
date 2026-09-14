import BrewCore
@testable import BrewUIComponents
import Foundation
import Testing

struct CaskFlowIconSourceTests {
    @Test func `cask icons use CDN then GitHub fallback`() {
        let urls = CaskFlowIconSource.urls(for: .cask(token: "arc"))

        #expect(urls.map(\.absoluteString) == [
            "https://cdn.jsdelivr.net/gh/alielsokary/CaskFlow@icons/arc.png",
            "https://raw.githubusercontent.com/alielsokary/CaskFlow/icons/arc.png",
        ])
    }

    @Test func `formulae do not request CaskFlow icons`() {
        #expect(CaskFlowIconSource.urls(for: .formula(name: "git")).isEmpty)
    }
}
