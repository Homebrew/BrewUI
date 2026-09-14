import AppKit
@testable import BrewUIComponents
import Foundation
import Testing

@MainActor
struct StandardEditingCommandsTests {
    @Test func `standard actions retain native selectors and command shortcuts`() {
        let actions = StandardEditingAction.allCases
        #expect(actions.map { NSStringFromSelector($0.selector) } == [
            "undo:", "redo:", "cut:", "copy:", "paste:", "delete:", "selectAll:",
        ])
        #expect(actions.map { $0.keyEquivalent.map(String.init) } == ["z", "z", "x", "c", "v", nil, "a"])
        #expect(actions.map(\.keyEquivalentModifierMask) == [
            [.command], [.command, .shift], [.command], [.command], [.command], [], [.command],
        ])
    }

    @Test func `explicit localization translates every editing label`() throws {
        try withBundle { bundle in
            let localization = AppLocalization(language: "zh-Hans", bundle: bundle)
            let labels = StandardEditingAction.allCases.map { $0.title(localization: localization) }

            #expect(labels == ["撤销", "重做", "剪切", "复制", "粘贴", "删除", "全选"])
        }
    }

    @Test func `native router resolves current target and dispatches only enabled actions`() {
        let responder = EditingResponder()
        var sent: [Selector] = []
        let router = NativeEditingActionRouter(target: { _ in responder }, send: { sent.append($0); return true })
        router.perform(.copy)
        responder.enabled = true
        router.perform(.copy)
        #expect(sent == [StandardEditingAction.copy.selector])
        #expect(!NativeEditingActionRouter(target: { _ in nil }).isEnabled(.copy))
    }

    private final class EditingResponder: NSObject, NSMenuItemValidation {
        var enabled = false
        func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            enabled && menuItem.action == StandardEditingAction.copy.selector
        }
    }

    @Test func `validation refresh follows the currently focused responder`() {
        let router = RecordingEditingRouter(enabledActions: [.undo, .copy])
        let state = StandardEditingValidationState(router: router)

        state.refresh()
        let first = StandardEditingAction.allCases.filter(state.isEnabled)

        router.enabledActions = [.redo, .paste]
        state.refresh()
        let second = StandardEditingAction.allCases.filter(state.isEnabled)

        #expect(first == [.undo, .copy] && second == [.redo, .paste])
    }

    @Test func `missing responder disables every command`() {
        let router = RecordingEditingRouter(enabledActions: [])
        let state = StandardEditingValidationState(router: router)

        state.refresh()

        #expect(StandardEditingAction.allCases.allSatisfy { !state.isEnabled($0) })
    }

    private final class RecordingEditingRouter: StandardEditingActionRouting {
        var enabledActions: Set<StandardEditingAction>
        var performed: [StandardEditingAction] = []

        init(enabledActions: Set<StandardEditingAction>) {
            self.enabledActions = enabledActions
        }

        func perform(_ action: StandardEditingAction) {
            performed.append(action)
        }

        func isEnabled(_ action: StandardEditingAction) -> Bool {
            enabledActions.contains(action)
        }
    }

    private func withBundle(_ body: (Bundle) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, strings) in [
            (
                "en",
                """
                "Undo" = "Undo";
                "Redo" = "Redo";
                "Cut" = "Cut";
                "Copy" = "Copy";
                "Paste" = "Paste";
                "Delete" = "Delete";
                "Select All" = "Select All";
                """,
            ),
            (
                "zh-Hans",
                "\"Undo\" = \"撤销\";\n\"Redo\" = \"重做\";\n\"Cut\" = \"剪切\";\n\"Copy\" = \"复制\";\n\"Paste\" = \"粘贴\";\n\"Delete\" = \"删除\";\n\"Select All\" = \"全选\";\n",
            ),
        ] {
            let folder = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try strings.write(to: folder.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }
        try body(#require(Bundle(url: root)))
    }
}
