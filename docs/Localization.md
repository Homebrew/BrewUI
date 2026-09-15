# Localization

BrewUI follows the macOS language: System Settings › General › Language & Region, or the per-app language under *Applications*. Anything without a translation falls back to English, so a partially translated language is fine to ship. Homebrew's own output in the console is always English.

## Translating

Every UI target keeps its strings in a String Catalog:

| Catalog | What it covers |
|---|---|
| `Homebrew/Localizable.xcstrings` | Sidebar, window titles, menus, crash dialog |
| `Sources/BrewUIComponents/Resources/Localizable.xcstrings` | Shared controls and error messages |
| `Sources/BrewFeatureInstalled/Resources/Localizable.xcstrings` | Installed and Upgrades tabs |
| `Sources/BrewFeatureDiscover/Resources/Localizable.xcstrings` | Discover tab |
| `Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings` | Doctor tab |
| `Sources/BrewFeatureConfig/Resources/Localizable.xcstrings` | Configuration tab |
| `Sources/BrewFeatureConsole/Resources/Localizable.xcstrings` | Console panel |
| `Sources/BrewFeatureSelfUpgrade/Resources/Localizable.xcstrings` | App self-upgrade banner |

The key is the English copy; each entry's comment says where it appears and what any `%@` / `%lld` stands for.

**In Xcode:** open a catalog, press `+` to add your language if it is not listed, and fill in the translations. Xcode marks what is still untranslated (*New*) and what needs another look after the English changed (*Needs review*).

**Without Xcode:** add a `localizations` entry to the string in the JSON:

```json
"License" : {
  "comment" : "Package detail row",
  "localizations" : {
    "en-GB" : { "stringUnit" : { "state" : "translated", "value" : "Licence" } }
  }
}
```

Two things to know:

- macOS only offers a language in the per-app picker if the **app** bundle ships it, so `Homebrew/Localizable.xcstrings` needs at least one translation in your language before the package catalogs matter. `scripts/localize status` warns when a language is missing there.
- Never leave a translation empty: an empty value renders as blank text rather than falling back to English. Remove the entry instead. `scripts/localize verify` catches this.

`scripts/localize status` shows how far each language is. CI prints the same table in the *Swift Quality* job summary.

## Writing copy

Only UI packages hold copy: `Sources/BrewUIComponents`, `Sources/BrewFeature*` and the `Homebrew` app. Lower layers throw typed error enums (`OperationFailure`, `BrewCommandError`, `BrewRepositoryError`) and `BrewUIComponents/Copy/BrewErrorCopy` words them. BrewUILint's `localization_layer` rule enforces the boundary.

Three call-site forms, checked by BrewUILint's `localized_copy` rule:

```swift
Text("Doctor", bundle: #bundle, comment: "Doctor tab heading")
Button(String(localized: "Run Again", bundle: #bundle, comment: "Doctor: re-run diagnostics")) { … }
Text(verbatim: "v\(version)")   // not copy: versions, package names, commands
```

- `#bundle` resolves to the package's own resource bundle. Without it a package string is looked up in the app bundle and silently never localises.
- The comment is for translators: where the string appears, and what interpolated values are. One line.
- Carry copy as `String`, never `LocalizedStringKey` — a key cannot carry a bundle. Shared components take `String` parameters and callers pass `String(localized:…)`.
- Debug-only UI and `#Preview` sample text use `Text(verbatim:)`, so developer strings never reach the catalogs.
- Text that must match `brew` word for word (the `brew doctor` preamble, remediation captions) stays verbatim.

### Keeping catalogs in sync

Xcode updates the catalogs on every build. From the command line, `scripts/localize sync` does the same using the compiler's string extraction. CI and the pre-commit hook run `scripts/localize sync --check` and fail if a catalog does not match the code, so a new string is never invisible to translators.

When English copy changes, the old key is marked *stale* (kept while it still has translations) and the new one appears as untranslated in every language. Delete stale entries once nothing needs them.

## Checking a build

- **Run with** `-AppleLanguages "(en-GB)"` to force a language.
- **Run with** `-NSShowNonLocalizedStrings YES`: any copy that bypasses localisation shows in capitals.
- **Scheme › Options › App Language › Double-Length Pseudolanguage** stretches every localised string; anything that does not stretch is verbatim.
