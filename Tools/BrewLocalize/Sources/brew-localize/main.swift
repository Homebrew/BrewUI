import BrewLocalizeCore
import Foundation

let usage = """
Usage: brew-localize <command> [--root <repo>]

  sync [--check]      Extract strings from each UI target and merge them into its catalog.
                      --check leaves catalogs untouched and fails if any would change.
  status [--markdown] Per-language translation totals across all catalogs.
  verify              Catalogs live only in UI targets and every string has a comment.
"""

struct Invocation {
    var command: String
    var flags: Set<String> = []
    var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    init?(arguments: [String]) {
        var arguments = arguments[...]
        guard let command = arguments.popFirst() else {
            return nil
        }
        self.command = command
        while let argument = arguments.popFirst() {
            if argument == "--root", let path = arguments.popFirst() {
                root = URL(fileURLWithPath: path)
            } else if argument.hasPrefix("--") {
                flags.insert(argument)
            } else {
                return nil
            }
        }
    }
}

func loadCatalogs(root: URL) throws -> [(location: CatalogLocation, catalog: StringCatalog)] {
    try CatalogLocation.discover(root: root).map { location in
        try (location, StringCatalog(contentsOf: root.appendingPathComponent(location.path)))
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let invocation = Invocation(arguments: Array(CommandLine.arguments.dropFirst())) else {
    fail(usage)
}

do {
    switch invocation.command {
    case "sync":
        let check = invocation.flags.contains("--check")
        let index = try CatalogSync.extract(root: invocation.root)
        var drifted: [CatalogSync.Outcome] = []
        for location in CatalogLocation.discover(root: invocation.root) {
            let outcome = try CatalogSync.sync(location, root: invocation.root, index: index, check: check)
            if outcome.changed {
                drifted.append(outcome)
            } else if !check {
                print("synced \(location.path)")
            }
        }
        if !drifted.isEmpty {
            for outcome in drifted {
                print(outcome.diff)
            }
            fail("\(drifted.count) catalog(s) out of date — run scripts/localize sync and stage the .xcstrings files.")
        }
        if check {
            print("string catalogs are in sync")
        }

    case "status":
        let status = try LocalizationStatus(catalogs: loadCatalogs(root: invocation.root))
        print(invocation.flags.contains("--markdown") ? StatusReport.markdown(status) : StatusReport.text(status))

    case "verify":
        let problems = try loadCatalogs(root: invocation.root).flatMap { location, catalog in
            CatalogVerification.problems(in: catalog, at: location)
        }
        for problem in problems {
            print(problem)
        }
        if !problems.isEmpty {
            fail("\(problems.count) catalog problem(s).")
        }
        print("string catalogs verified")

    default:
        fail(usage)
    }
} catch {
    fail("brew-localize: \(error)")
}
