//
//  BrewUITestingFixturePayload.swift
//  BrewUITestContract
//

import Foundation

/// Launch environment keys shared by the app and `BrewUITests`, so neither side spells a raw string.
public enum BrewUITestingEnvironmentKey {
    /// Its presence is what puts the app in test mode.
    public static let launchArgument = "-uiTesting"
    public static let scenario = "BREW_UITEST_SCENARIO"
    public static let payload = "BREW_UITEST_FIXTURE_PAYLOAD"
    /// Written by the app once the tree is installed, not by the test runner.
    public static let fixturesRoot = "BREW_UITEST_FIXTURES"
}

/// The fixture tree, in transit: relative paths to bytes, JSON then deflated then base64'd.
///
/// It travels in the launch environment rather than on disk because a path the test runner can write
/// is not necessarily one the app can read and execute from, and the failure is an opaque `EPERM` on
/// whichever side loses. Letting the app write the files it will run removes the question.
public struct BrewUITestingFixturePayload: Codable, Sendable {
    public let files: [String: Data]
    /// Which entry in ``files`` needs the executable bit; `nil` installs none, which is how the
    /// brew-not-found scenario is expressed.
    public let executable: String?

    public init(files: [String: Data], executable: String?) {
        self.files = files
        self.executable = executable
    }

    public func encoded() throws -> String {
        let json = try JSONEncoder().encode(self)
        let compressed = try (json as NSData).compressed(using: .zlib)
        return (compressed as Data).base64EncodedString()
    }

    public static func decoded(from encoded: String) throws -> BrewUITestingFixturePayload {
        guard let compressed = Data(base64Encoded: encoded) else {
            throw BrewUITestingFixtureError.malformedPayload
        }
        let json = try (compressed as NSData).decompressed(using: .zlib)
        return try JSONDecoder().decode(BrewUITestingFixturePayload.self, from: json as Data)
    }
}

public enum BrewUITestingFixtureError: Error {
    case malformedPayload
}
