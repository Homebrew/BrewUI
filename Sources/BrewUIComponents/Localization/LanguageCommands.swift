/*
 * [INPUT]: 依赖 SwiftUI Commands 与 App 持有的 LanguagePreferences
 * [OUTPUT]: 提供原生语言菜单，语言以自身名称展示并立即更新界面
 * [POS]: 用户意图进入语言状态的入口；不重建窗口或触发后台任务
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import BrewAccessibilityID
import SwiftUI

public struct LanguageCommands: Commands {
    private let preferences: LanguagePreferences

    public init(preferences: LanguagePreferences) {
        self.preferences = preferences
    }

    public var body: some Commands {
        CommandGroup(after: .appSettings) {
            Menu(preferences.localization.string("Language")) {
                Toggle(preferences.localization.string("Follow System"), isOn: selection(nil))
                    .axid(.languageSystem)
                Divider()
                ForEach(preferences.availableLanguages, id: \.self) { language in
                    Toggle(languageName(language), isOn: selection(language))
                        .axid(.languageOption(language))
                }
            }
            .axid(.languageMenu)
        }
    }

    private func selection(_ language: String?) -> Binding<Bool> {
        Binding(get: { preferences.selectedLanguage == language }, set: { _ in preferences.select(language) })
    }

    private func languageName(_ language: String) -> String {
        Locale(identifier: language).localizedString(forIdentifier: language) ?? language
    }
}
