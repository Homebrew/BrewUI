import Foundation

@MainActor
private func respond() -> Int32 {
    guard let password = AdministratorPasswordPrompt().run() else {
        return EXIT_FAILURE
    }
    do {
        try FileHandle.standardOutput.write(contentsOf: Data((password + "\n").utf8))
        return EXIT_SUCCESS
    } catch {
        FileHandle.standardError.write(Data("HomebrewAskpassHelper: could not send authentication response\n".utf8))
        return EXIT_FAILURE
    }
}

/// Packaging smoke check: finds the app bundle and its string catalog, then loads the prompt without showing it.
/// Source-language copy is the catalog key, so an untranslated string is not a separate `.strings` entry.
@MainActor
private func validatePackaging() -> Int32 {
    guard let bundle = AskpassAppBundle.locate() else {
        FileHandle.standardError.write(Data("HomebrewAskpassHelper: enclosing app bundle not found\n".utf8))
        return EXIT_FAILURE
    }
    let catalog = bundle.localizations.contains { localization in
        bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization) != nil
    }
    guard catalog else {
        FileHandle.standardError.write(Data("HomebrewAskpassHelper: app string catalog not found\n".utf8))
        return EXIT_FAILURE
    }
    _ = AdministratorPasswordPrompt()
    return EXIT_SUCCESS
}

exit(CommandLine.arguments.dropFirst().elementsEqual(["--validate-packaging"]) ? validatePackaging() : respond())
