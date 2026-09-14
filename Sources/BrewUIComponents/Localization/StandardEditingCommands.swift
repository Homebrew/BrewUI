/*
 * [INPUT]: 依赖 SwiftUI CommandGroup、AppKit responder chain 与 AppLocalization
 * [OUTPUT]: 本地化编辑命令及可刷新的原生启用校验，不缓存 responder 或已翻译标题
 * [POS]: 编辑菜单的声明边界；动作执行时重新解析焦点，业务状态不参与语言切换
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import AppKit
import Observation
import SwiftUI

public struct StandardEditingCommands: Commands {
    private let localization: AppLocalization
    private let state: StandardEditingValidationState

    public init(localization: AppLocalization, state: StandardEditingValidationState) {
        self.localization = localization
        self.state = state
    }

    public var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            command(.undo)
            command(.redo)
        }
        CommandGroup(replacing: .pasteboard) {
            command(.cut)
            command(.copy)
            command(.paste)
            command(.delete)
            command(.selectAll)
        }
    }

    private func command(_ action: StandardEditingAction) -> some View {
        Button(action.title(localization: localization)) { state.perform(action) }
            .disabled(!state.isEnabled(action))
            .keyboardShortcut(action.shortcut)
    }
}

enum StandardEditingAction: String, CaseIterable {
    case undo, redo, cut, copy, paste, delete, selectAll

    var selector: Selector {
        NSSelectorFromString(rawValue + ":")
    }

    var keyEquivalent: Character? {
        switch self {
        case .undo, .redo: "z"
        case .cut: "x"
        case .copy: "c"
        case .paste: "v"
        case .selectAll: "a"
        case .delete: nil
        }
    }

    var keyEquivalentModifierMask: NSEvent.ModifierFlags {
        switch self {
        case .redo: [.command, .shift]
        case .delete: []
        default: [.command]
        }
    }

    var shortcut: KeyboardShortcut? {
        keyEquivalent.map { KeyboardShortcut(KeyEquivalent($0), modifiers: self == .redo ? [.command, .shift] : [.command]) }
    }

    func title(localization: AppLocalization) -> String {
        let key: String.LocalizationValue = switch self {
        case .undo: "Undo"
        case .redo: "Redo"
        case .cut: "Cut"
        case .copy: "Copy"
        case .paste: "Paste"
        case .delete: "Delete"
        case .selectAll: "Select All"
        }
        return localization.string(key)
    }
}

@MainActor
protocol StandardEditingActionRouting {
    func isEnabled(_ action: StandardEditingAction) -> Bool
    func perform(_ action: StandardEditingAction)
}

@MainActor
struct NativeEditingActionRouter: StandardEditingActionRouting {
    var target: (Selector) -> AnyObject? = { NSApp.target(forAction: $0) as AnyObject? }
    var send: (Selector) -> Bool = { NSApp.sendAction($0, to: nil, from: nil) }

    func isEnabled(_ action: StandardEditingAction) -> Bool {
        guard let responder = target(action.selector) else { return false }
        let item = NSMenuItem(title: action.rawValue, action: action.selector, keyEquivalent: action.keyEquivalent.map(String.init) ?? "")
        item.keyEquivalentModifierMask = action.keyEquivalentModifierMask
        if let validator = responder as? NSMenuItemValidation { return validator.validateMenuItem(item) }
        if let validator = responder as? NSUserInterfaceValidations { return validator.validateUserInterfaceItem(item) }
        return true
    }

    func perform(_ action: StandardEditingAction) {
        guard isEnabled(action) else { return }
        _ = send(action.selector)
    }
}

@MainActor
@Observable
public final class StandardEditingValidationState {
    private var enabled: Set<StandardEditingAction> = []
    private let router: any StandardEditingActionRouting

    public init() {
        router = NativeEditingActionRouter()
    }

    init(router: any StandardEditingActionRouting) {
        self.router = router
    }

    public func refresh() {
        let next = Set(StandardEditingAction.allCases.filter(router.isEnabled))
        if next != enabled { enabled = next }
    }

    func isEnabled(_ action: StandardEditingAction) -> Bool {
        enabled.contains(action)
    }

    func perform(_ action: StandardEditingAction) {
        router.perform(action)
        refresh()
    }
}
