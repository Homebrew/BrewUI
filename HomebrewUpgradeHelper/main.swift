//
//  main.swift
//  HomebrewUpgradeHelper
//

import BrewSelfUpgradeContract
import BrewSelfUpgradeHelperCore
import Foundation

let arguments = CommandLine.arguments

guard let flagIndex = arguments.firstIndex(of: SelfUpgradeHandoffDefaults.specPathArgument),
      arguments.index(after: flagIndex) < arguments.endIndex
else {
    FileHandle.standardError.write(
        Data("HomebrewUpgradeHelper: usage: \(SelfUpgradeHandoffDefaults.specPathArgument) <path-to-spec.json>\n".utf8),
    )
    exit(EXIT_FAILURE)
}

let specPath = arguments[arguments.index(after: flagIndex)]

let spec: SelfUpgradeHandoffSpec
do {
    spec = try SelfUpgradeHandoffSpec.decoded(from: Data(contentsOf: URL(fileURLWithPath: specPath)))
} catch {
    FileHandle.standardError.write(
        Data("HomebrewUpgradeHelper: could not read the handoff spec at \(specPath): \(error)\n".utf8),
    )
    exit(EXIT_FAILURE)
}

let log = SelfUpgradeLog(fileURL: URL(fileURLWithPath: spec.logFilePath))
await UpgradeHelper(spec: spec, log: log).run()

// Not in a `defer`, which `exit()` would skip.
try? FileManager.default.removeItem(atPath: specPath)
exit(EXIT_SUCCESS)
