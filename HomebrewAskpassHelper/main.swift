import BrewUIComponents
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

/// Packaging smoke check: loads the prompt and its adjacent resource bundle without showing it.
@MainActor
private func validatePackaging() -> Int32 {
    guard Bundle.main.url(forResource: "BrewKit_BrewUIComponents", withExtension: "bundle") != nil else {
        FileHandle.standardError.write(Data("HomebrewAskpassHelper: resource bundle not found beside the helper\n".utf8))
        return EXIT_FAILURE
    }
    _ = AdministratorPasswordPrompt()
    return EXIT_SUCCESS
}

exit(CommandLine.arguments.dropFirst().elementsEqual(["--validate-packaging"]) ? validatePackaging() : respond())
