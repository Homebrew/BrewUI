//
//  DoctorJSON.swift
//  BrewRepositories
//

import Foundation

/// Wire shape of `brew doctor --json`. The switch is `hidden:` in `Homebrew/cmd/doctor.rb`, so the schema
/// is not a contract: every field is optional and unknown ones are ignored.
struct DoctorJSON: Decodable {
    var tier: DoctorJSONTier
    var findings: [DoctorJSONFinding]

    private enum CodingKeys: String, CodingKey {
        case tier, findings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tier = try container.decodeIfPresent(DoctorJSONTier.self, forKey: .tier) ?? .unknown("")
        findings = try container.decodeIfPresent([DoctorJSONFinding].self, forKey: .findings) ?? []
    }
}

struct DoctorJSONFinding: Decodable {
    /// The warning as brew would print it.
    var text: String
    /// Support tier of the configuration this finding indicates, *not* a ranking of how bad it is.
    var tier: DoctorJSONTier
    var affects: [String]
    var links: [String]
    var remediation: DoctorJSONRemediation?

    private enum CodingKeys: String, CodingKey {
        case text, tier, affects, links, remediation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        tier = try container.decodeIfPresent(DoctorJSONTier.self, forKey: .tier) ?? .unknown("")
        affects = try container.decodeIfPresent([String].self, forKey: .affects) ?? []
        links = try container.decodeIfPresent([String].self, forKey: .links) ?? []
        remediation = try container.decodeIfPresent(DoctorJSONRemediation.self, forKey: .remediation)
    }
}

struct DoctorJSONRemediation: Decodable {
    /// The only source of anything the app offers to run: `text` regularly contains destructive lines
    /// (`sudo rm -rf …`) that brew deliberately left out of this array.
    var commands: [String]
    var text: String

    private enum CodingKeys: String, CodingKey {
        case commands, text
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commands = try container.decodeIfPresent([String].self, forKey: .commands) ?? []
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
    }
}

/// Homebrew's support tier. Serialised as a number for tiers 1–3 and as a string for `unsupported`
/// (`Finding#tier` is `T.any(Integer, Symbol)`); anything else is kept verbatim rather than rejected.
enum DoctorJSONTier: Decodable, Equatable {
    case numbered(Int)
    case unsupported
    case unknown(String)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int.self) {
            self = .numbered(number)
            return
        }
        let text = (try? container.decode(String.self)) ?? ""
        switch text.lowercased() {
        case "unsupported":
            self = .unsupported
        default:
            self = Int(text).map { .numbered($0) } ?? .unknown(text)
        }
    }
}
