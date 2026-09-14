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
