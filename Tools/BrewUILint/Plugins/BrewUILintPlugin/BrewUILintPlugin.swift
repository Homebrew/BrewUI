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
        let workDirectory = context.pluginWorkDirectoryURL
        return sourceFiles.map(\.url).compactMap {
            createBuildCommand(for: $0, with: brewUILint.url, workDirectory: workDirectory)
        }
    }

    func createBuildCommand(
        for inputPath: URL,
        with executable: URL,
        workDirectory: URL,
    ) -> Command? {
        guard inputPath.pathExtension == "swift" else {
            return nil
        }

        let fileName = inputPath.lastPathComponent
        let sentinelName = inputPath.path
            .replacingOccurrences(of: "/", with: "_")
            .appending(".sentinel")
        let sentinel = workDirectory.appending(path: sentinelName)
        return .buildCommand(
            displayName: "BrewUILint (\(fileName))",
            executable: executable,
            arguments: [inputPath.path, "--sentinel", sentinel.path],
            inputFiles: [inputPath],
            outputFiles: [sentinel],
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
            let workDirectory = context.pluginWorkDirectoryURL
            return target.inputFiles.map(\.url).compactMap {
                createBuildCommand(for: $0, with: brewUILint.url, workDirectory: workDirectory)
            }
        }
    }
#endif
