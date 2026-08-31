//
//  BrewColorAsset.swift
//  BrewUIComponentsTests
//

import Foundation

/// Reads the design-system colour sets out of `Media.xcassets`.
///
/// Parsed from source rather than resolved through `NSColor(named:bundle:)`: SwiftPM copies
/// `.xcassets` into the test bundle uncompiled, so a runtime lookup returns `nil` under `swift test`.
nonisolated enum BrewColorAsset {
    enum Appearance: String, CaseIterable {
        case light
        case dark
        case highContrastLight
        case highContrastDark

        var isDark: Bool {
            self == .dark || self == .highContrastDark
        }

        var isHighContrast: Bool {
            self == .highContrastLight || self == .highContrastDark
        }

        /// The standard-contrast appearance with the same luminosity.
        var standardContrast: Appearance {
            isDark ? .dark : .light
        }

        static let standard: [Appearance] = [.light, .dark]
        static let highContrast: [Appearance] = [.highContrastLight, .highContrastDark]
    }

    enum LoadError: Error, CustomStringConvertible {
        case missingColorSet(String)
        case unreadable(String, underlying: any Error)
        case unsupportedColorSpace(String, String)
        case unsupportedComponent(String, String)
        case noEntry(String, Appearance)

        var description: String {
            switch self {
            case let .missingColorSet(name):
                "No colour set named \(name) in Media.xcassets"
            case let .unreadable(name, underlying):
                "Could not read colour set \(name): \(underlying)"
            case let .unsupportedColorSpace(name, space):
                "Colour set \(name) uses unsupported colour space \(space) — only srgb is handled"
            case let .unsupportedComponent(name, value):
                "Colour set \(name) has an unparsable component \(value)"
            case let .noEntry(name, appearance):
                "Colour set \(name) has no \(appearance.rawValue) entry"
            }
        }
    }

    /// Which appearances a colour set declares an entry for.
    static func declaredAppearances(_ name: String) throws -> Set<Appearance> {
        let url = catalogueURL.appending(path: "\(name).colorset/Contents.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LoadError.missingColorSet(name)
        }
        let document: ColorSetDocument
        do {
            document = try JSONDecoder().decode(ColorSetDocument.self, from: Data(contentsOf: url))
        } catch {
            throw LoadError.unreadable(name, underlying: error)
        }
        let entries = document.colors.filter { $0.color != nil }
        return Set(Appearance.allCases.filter { appearance in
            entries.contains { $0.matches(appearance) }
        })
    }

    /// Every colour set in the catalogue, sorted.
    static func allNames() throws -> [String] {
        let contents = try FileManager.default.contentsOfDirectory(atPath: catalogueURL.path)
        return contents
            .filter { $0.hasSuffix(".colorset") }
            .map { String($0.dropLast(".colorset".count)) }
            .sorted()
    }

    /// Exact match on both axes, otherwise the universal entry.
    ///
    /// No cleverer fallback: AppKit's rule for relaxing a *missing* variant is not observable unless
    /// the system "Increase contrast" setting is on, so every colour set that varies by luminosity
    /// states its high-contrast dark value outright — enforced by ``BrewColorAssetTests``.
    static func color(_ name: String, _ appearance: Appearance) throws -> SRGBColor {
        let url = catalogueURL.appending(path: "\(name).colorset/Contents.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LoadError.missingColorSet(name)
        }
        let document: ColorSetDocument
        do {
            document = try JSONDecoder().decode(ColorSetDocument.self, from: Data(contentsOf: url))
        } catch {
            throw LoadError.unreadable(name, underlying: error)
        }

        let entries = document.colors.filter { $0.color != nil }
        let match = entries.first { $0.matches(appearance) } ?? entries.first(where: \.isUniversal)
        guard let entry = match, let color = entry.color else {
            throw LoadError.noEntry(name, appearance)
        }
        guard color.colorSpace == "srgb" else {
            throw LoadError.unsupportedColorSpace(name, color.colorSpace)
        }

        func channel(_ raw: String) throws -> Double {
            guard let value = Self.channelValue(raw) else {
                throw LoadError.unsupportedComponent(name, raw)
            }
            return value
        }

        return try SRGBColor(
            red: channel(color.components.red),
            green: channel(color.components.green),
            blue: channel(color.components.blue),
            alpha: channel(color.components.alpha),
        )
    }

    /// Asset-catalogue components are strings in one of three notations: `"0.910"`, `"0xE8"` or `"235"`.
    private static func channelValue(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("0x") {
            return UInt8(trimmed.dropFirst(2), radix: 16).map { Double($0) / 255 }
        }
        if trimmed.contains(".") {
            return Double(trimmed)
        }
        return UInt8(trimmed).map { Double($0) / 255 }
    }

    /// Four levels up from this file is the package root.
    private static var catalogueURL: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/BrewUIComponents/Resources/Media.xcassets")
    }
}

// MARK: - Catalogue JSON

private nonisolated struct ColorSetDocument: Decodable {
    let colors: [ColorSetEntry]
}

private nonisolated struct ColorSetEntry: Decodable {
    let appearances: [ColorSetAppearance]?
    let color: ColorSetColor?

    var isUniversal: Bool {
        appearances?.isEmpty ?? true
    }

    /// Both axes must agree: no `luminosity` means light, no `contrast` means standard.
    func matches(_ appearance: BrewColorAsset.Appearance) -> Bool {
        guard let appearances, !appearances.isEmpty else {
            return false
        }
        let declaresDark = appearances.contains { $0.appearance == "luminosity" && $0.value == "dark" }
        let declaresHighContrast = appearances.contains { $0.appearance == "contrast" && $0.value == "high" }
        return declaresDark == appearance.isDark && declaresHighContrast == appearance.isHighContrast
    }
}

private nonisolated struct ColorSetAppearance: Decodable {
    let appearance: String
    let value: String
}

private nonisolated struct ColorSetColor: Decodable {
    let colorSpace: String
    let components: ColorSetComponents

    enum CodingKeys: String, CodingKey {
        case colorSpace = "color-space"
        case components
    }
}

private nonisolated struct ColorSetComponents: Decodable {
    let red: String
    let green: String
    let blue: String
    let alpha: String
}
