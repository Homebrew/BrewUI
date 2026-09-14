@testable import BrewFeatureConfig
import Testing

struct LanguageSettingsPresentationTests {
    @Test func `restart alert is shown only when language changes`() {
        #expect(LanguageSettingsPresentation.shouldPresentRestartAlert(from: .system, to: .english))
        #expect(LanguageSettingsPresentation.shouldPresentRestartAlert(from: .english, to: .simplifiedChinese))
        #expect(!LanguageSettingsPresentation.shouldPresentRestartAlert(from: .english, to: .english))
    }
}
