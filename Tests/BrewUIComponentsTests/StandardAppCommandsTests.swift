import AppKit
@testable import BrewUIComponents
import Testing

@MainActor
struct StandardAppCommandsTests {
    @Test func `no window disables window commands`() {
        let state = StandardAppCommandState()
        state.refresh(styleMask: nil, hasHiddenApplications: false)
        #expect(!state.canClose && !state.canMinimize && !state.canZoom && !state.canUnhide)
    }

    @Test func `window capabilities and hidden apps determine availability`() {
        let state = StandardAppCommandState()
        state.refresh(styleMask: [.closable, .resizable], hasHiddenApplications: true)
        #expect(state.canClose && !state.canMinimize && state.canZoom && state.canUnhide)
        state.refresh(styleMask: [.miniaturizable], hasHiddenApplications: false)
        #expect(!state.canClose && state.canMinimize && !state.canZoom && !state.canUnhide)
    }
}
