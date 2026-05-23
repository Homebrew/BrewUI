import Foundation
import PackagePlugin

@main
struct BrewUILintPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target,
    ) throws -> [Command] {
        guard let sourceFiles = target.sourceModule?.sourceFiles else {
            return []
        }

        let brewUILint = try context.tool(named: "BrewUILint")
        return sourceFiles.map(\.url).compactMap {
            createBuildCommand(for: $0, with: brewUILint.url)
        }
    }

    func createBuildCommand(for inputPath: URL, with executable: URL) -> Command? {
        guard inputPath.pathExtension == "swift" else {
            return nil
        }

        let fileName = inputPath.lastPathComponent
        return .buildCommand(
            displayName: "BrewUILint (\(fileName))",
            executable: executable,
            arguments: [inputPath.path],
            inputFiles: [inputPath],
            outputFiles: [],
        )
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension BrewUILintPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(
            context: XcodePluginContext,
            target: XcodeTarget,
        ) throws -> [Command] {
            let brewUILint = try context.tool(named: "BrewUILint")
            return target.inputFiles.map(\.url).compactMap {
                createBuildCommand(for: $0, with: brewUILint.url)
            }
        }
    }
#endif
