import BrewAccessibilityID
import SwiftUI

public struct LanguageCommands: Commands {
    private let preferences: LanguagePreferences

    private let onSelect: (String?) -> Void
    private let onReopen: () -> Void

    public init(preferences: LanguagePreferences, onSelect: @escaping (String?) -> Void, onReopen: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onReopen = onReopen
        self.preferences = preferences
    }

    public var body: some Commands {
        CommandGroup(after: .appSettings) {
            Menu(preferences.localization.string("Language")) {
                Text(preferences.localization.string("Current language: \(languageName(preferences.activeLanguage))"))
                Divider()
                Toggle(preferences.localization.string("Follow System"), isOn: selection(nil))
                    .axid(.languageSystem)
                Divider()
                ForEach(preferences.availableLanguages, id: \.self) { language in
                    Toggle(languageName(language), isOn: selection(language))
                        .axid(.languageOption(language))
                }
                if preferences.hasPendingChange {
                    Divider()
                    Text(preferences.localization.string("Applies on next launch"))
                    Button(preferences.localization.string("Reopen Homebrew…"), action: onReopen)
                }
            }
            .axid(.languageMenu)
        }
    }

    private func selection(_ language: String?) -> Binding<Bool> {
        Binding(get: { preferences.selectedLanguage == language }, set: { _ in onSelect(language) })
    }

    private func languageName(_ language: String) -> String {
        Locale(identifier: language).localizedString(forIdentifier: language) ?? language
    }
}
