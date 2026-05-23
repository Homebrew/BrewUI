import Foundation

@main
struct BrewUILintMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard !arguments.isEmpty else {
            fputs("usage: BrewUILint <file>...\n", stderr)
            exit(2)
        }

        do {
            let violations = try Runner.lint(files: arguments)
            for violation in violations {
                print(violation.xcodeFormatted)
            }
            exit(violations.isEmpty ? 0 : 1)
        } catch {
            fputs("BrewUILint: \(error)\n", stderr)
            exit(2)
        }
    }
}
