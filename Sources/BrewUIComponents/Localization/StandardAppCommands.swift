import AppKit
import Observation
import SwiftUI

public struct StandardAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    private let state: StandardAppCommandState
    private let localization: AppLocalization
    private let mainWindowID: String

    public init(localization: AppLocalization, mainWindowID: String, state: StandardAppCommandState) {
        self.state = state
        self.localization = localization
        self.mainWindowID = mainWindowID
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(localization.string("New Window")) { openWindow(id: mainWindowID) }
                .keyboardShortcut("n")
        }
        CommandGroup(replacing: .saveItem) {
            Button(localization.string("Close")) { state.window?.performClose(nil) }
                .keyboardShortcut("w")
                .disabled(!state.canClose)
            Button(localization.string("Close All")) { dismissWindow(id: mainWindowID) }
                .keyboardShortcut("w", modifiers: [.command, .option])
                .disabled(!state.canClose)
        }
        CommandGroup(replacing: .windowSize) {
            Button(localization.string("Minimize")) { state.window?.performMiniaturize(nil) }
                .keyboardShortcut("m")
                .disabled(!state.canMinimize)
            Button(localization.string("Zoom")) { state.window?.performZoom(nil) }
                .disabled(!state.canZoom)
        }
        CommandGroup(replacing: .appInfo) {
            Button(localization.string("About Homebrew")) {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
        }
        CommandGroup(replacing: .appVisibility) {
            Button(localization.string("Hide Homebrew")) { NSApp.hide(nil) }
                .keyboardShortcut("h")
            Button(localization.string("Hide Others")) { NSApp.hideOtherApplications(nil) }
                .keyboardShortcut("h", modifiers: [.command, .option])
            Button(localization.string("Show All")) { NSApp.unhideAllApplications(nil) }
                .disabled(!state.canUnhide)
        }
        CommandGroup(replacing: .appTermination) {
            Button(localization.string("Quit Homebrew")) { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

/// 只保存菜单启用状态；窗口与应用动作仍由 AppKit/SwiftUI 拥有。
@MainActor
@Observable
public final class StandardAppCommandState {
    public private(set) var canClose = false
    public private(set) var canMinimize = false
    public private(set) var canZoom = false
    public private(set) var canUnhide = false
    var window: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }

    public init() {}

    public func refresh() {
        refresh(
            styleMask: window?.styleMask,
            hasHiddenApplications: NSWorkspace.shared.runningApplications.contains { $0.isHidden },
        )
    }

    func refresh(styleMask: NSWindow.StyleMask?, hasHiddenApplications: Bool) {
        canClose = styleMask?.contains(.closable) == true
        canMinimize = styleMask?.contains(.miniaturizable) == true
        canZoom = styleMask?.contains(.resizable) == true
        canUnhide = hasHiddenApplications
    }
}
