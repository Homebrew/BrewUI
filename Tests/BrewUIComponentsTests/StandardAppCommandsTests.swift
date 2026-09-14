/*
 * [INPUT]: 依赖标准窗口样式与 StandardAppCommandState
 * [OUTPUT]: 验证无窗口和受限窗口的命令启用边界，不创建或激活窗口
 * [POS]: 应用命令状态契约；不触发隐藏、退出或关闭操作
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
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
