import Foundation

@main
struct BrewUILintMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        // --sentinel <path> is optional: the build-tool plugin passes it so SwiftPM
        // has an output file to track for incremental builds. Direct invocations
        // (e.g. CI running over many files via xargs) omit it.
        var sourceFiles: [String] = []
        var sentinelPath: String?
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            if argument == "--sentinel" {
                let next = arguments.index(after: index)
                guard next < arguments.endIndex else {
                    fputs("BrewUILint: --sentinel requires a path\n", stderr)
                    exit(2)
                }
                sentinelPath = arguments[next]
                index = arguments.index(after: next)
            } else {
                sourceFiles.append(argument)
                index = arguments.index(after: index)
            }
        }

        guard !sourceFiles.isEmpty else {
            fputs("Usage: BrewUILint <source-file>... [--sentinel <path>]\n", stderr)
            exit(2)
        }

        do {
            let violations = try Runner.lint(files: sourceFiles)
            for violation in violations {
                print(violation.xcodeFormatted) // emits "...: error: ..."
            }
            if violations.isEmpty {
                if let sentinelPath {
                    FileManager.default.createFile(atPath: sentinelPath, contents: Data())
                }
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
