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

exit(respond())
