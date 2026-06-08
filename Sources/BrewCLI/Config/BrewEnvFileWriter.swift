//
//  BrewEnvFileWriter.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Renders a ``BrewEnvFile`` back to its on-disk shell representation.
///
/// `brew` itself loads each line with `read -r line; export "${line?}"` — no shell evaluation, no
/// quote stripping. So we emit raw `KEY=value`: any quoting in the value would become part of the
/// value `brew` sees. Lines that came from the parser carry their original substring as `raw` and
/// are re-emitted verbatim, keeping unedited files byte-identical on disk. Refuses to render values
/// containing literal newlines, which `brew`'s line-oriented loader has no way to honour.
public enum BrewEnvFileWriter {
    public static func render(_ file: BrewEnvFile) throws -> String {
        var rendered: [String] = []
        rendered.reserveCapacity(file.lines.count)
        for line in file.lines {
            try rendered.append(render(line: line))
        }
        let joined = rendered.joined(separator: "\n")
        return joined.isEmpty ? "" : joined + "\n"
    }

    private static func render(line: BrewEnvFileLine) throws -> String {
        switch line {
        case .blank:
            return ""
        case let .comment(text):
            return text
        case let .entry(key, value, raw):
            if let raw {
                return raw
            }
            // brew's file is line-oriented (`read -r line`); there's no escape it honours for a
            // literal newline in a value. Refuse rather than corrupt.
            guard !value.contains("\n") else {
                throw BrewEnvFileWriterError.newlineInValue(key: key)
            }
            return "\(key)=\(value)"
        case let .inert(rawText, _):
            return rawText
        }
    }
}

public enum BrewEnvFileWriterError: Error, Equatable, Sendable {
    /// The value for `key` contained a literal newline. `brew`'s loader is line-oriented and has no
    /// escape for embedded newlines.
    case newlineInValue(key: String)
}
