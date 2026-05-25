import Foundation

@main
struct BrewUILintMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 else {
            fputs("Usage: BrewUILint <source-file> <sentinel-path>\n", stderr)
            exit(2)
        }

        let sourceFile = arguments[0]
        let sentinelPath = arguments[1]

        do {
            let violations = try Runner.lint(files: [sourceFile])
            for violation in violations {
                print(violation.xcodeFormatted) // emits "...: error: ..."
            }
            if violations.isEmpty {
                FileManager.default.createFile(atPath: sentinelPath, contents: Data())
                exit(0)
            } else {
                exit(1)
            }
        } catch {
            fputs("BrewUILint: \(error)\n", stderr)
            exit(2)
        }
    }
}
