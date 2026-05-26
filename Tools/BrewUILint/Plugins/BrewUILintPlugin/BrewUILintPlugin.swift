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
        return try makeAllFilesCommand(
            with: context.tool(named: "BrewUILint").url,
            workDirectory: context.pluginWorkDirectoryURL,
            sourceURLs: sourceFiles.map(\.url),
        ).map { [$0] } ?? []
    }

    /// Lints every Swift source in the target with a single invocation so rules that need
    /// cross-file context (e.g. `NonisolatedExtensionRule`, which has to know what types are
    /// declared `nonisolated` in *other* files) see the whole module. Any source change
    /// re-runs the lint pass, but it's cheap once `BrewUILint` itself is built — sub-second
    /// for the BrewUI tree.
    func makeAllFilesCommand(
        with executable: URL,
        workDirectory: URL,
        sourceURLs: [URL],
    ) -> Command? {
        let swiftSources = sourceURLs.filter { $0.pathExtension == "swift" }
        guard !swiftSources.isEmpty else {
            return nil
        }
        let sentinel = workDirectory.appending(path: "BrewUILint.sentinel")
        let arguments = swiftSources.map(\.path) + ["--sentinel", sentinel.path]
        return .buildCommand(
            displayName: "BrewUILint (\(swiftSources.count) files)",
            executable: executable,
            arguments: arguments,
            inputFiles: swiftSources,
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
            try makeAllFilesCommand(
                with: context.tool(named: "BrewUILint").url,
                workDirectory: context.pluginWorkDirectoryURL,
                sourceURLs: target.inputFiles.map(\.url),
            ).map { [$0] } ?? []
        }
    }
#endif
