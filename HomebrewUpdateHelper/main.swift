//
//  main.swift
//  HomebrewUpdateHelper
//

import BrewSelfUpdateContract
import BrewSelfUpdateHelperCore
import Foundation

let arguments = CommandLine.arguments

guard let flagIndex = arguments.firstIndex(of: SelfUpdateHandoffDefaults.specPathArgument),
      arguments.index(after: flagIndex) < arguments.endIndex
else {
    FileHandle.standardError.write(
        Data("HomebrewUpdateHelper: usage: \(SelfUpdateHandoffDefaults.specPathArgument) <path-to-spec.json>\n".utf8),
    )
    exit(EXIT_FAILURE)
}

let specPath = arguments[arguments.index(after: flagIndex)]

let spec: SelfUpdateHandoffSpec
do {
    spec = try SelfUpdateHandoffSpec.decoded(from: Data(contentsOf: URL(fileURLWithPath: specPath)))
} catch {
    FileHandle.standardError.write(
        Data("HomebrewUpdateHelper: could not read the handoff spec at \(specPath): \(error)\n".utf8),
    )
    exit(EXIT_FAILURE)
}

/// Only reachable once the spec is decoded: the log's location is one of the things it carries.
let log = SelfUpdateLog(fileURL: URL(fileURLWithPath: spec.logFilePath))
await UpdateHelper(spec: spec, log: log).run()

// Not in a `defer`, which `exit()` would skip.
try? FileManager.default.removeItem(atPath: specPath)
exit(EXIT_SUCCESS)
