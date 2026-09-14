import BrewAppEnvironment

enum LanguageSettingsPresentation {
    static func shouldPresentRestartAlert(from oldLanguage: AppLanguage, to newLanguage: AppLanguage) -> Bool {
        oldLanguage != newLanguage
    }
}
