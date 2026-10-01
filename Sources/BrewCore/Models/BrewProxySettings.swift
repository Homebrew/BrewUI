//
//  BrewProxySettings.swift
//  BrewCore
//

import Foundation

/// User-facing proxy configuration persisted as `brew.env` keys for Homebrew's own download stack.
///
/// Shaped like a manual IDE proxy form: one mode, one type, host + port, an exclusion list and
/// optional credentials. The store maps that shape onto `http_proxy` / `https_proxy` / `all_proxy` /
/// `no_proxy`. Automatic PAC discovery is not modelled — `brew.env` and curl do not consume it.
public struct BrewProxySettings: Equatable, Sendable {
    /// `none` removes user proxy keys, allowing installation and system configuration to apply. `manual` writes the composed URL from ``type``/``host``/``port``.
    public enum Mode: String, CaseIterable, Sendable {
        case none
        case manual
    }

    /// Which proxy protocol the manual entry speaks.
    public enum ProxyType: String, CaseIterable, Sendable {
        /// HTTP proxy: `http_proxy` and `https_proxy` share one `http://` URL.
        case http
        /// SOCKS proxy: `all_proxy` gets a `socks5://` URL.
        case socks
    }

    public var mode: Mode
    public var type: ProxyType
    private var originalScheme: String?

    public var host: String
    public var port: String
    public var noProxy: String
    public var usesAuthentication: Bool
    public var username: String
    public var password: String

    public init(
        mode: Mode = .none,
        type: ProxyType = .http,
        host: String = "",
        port: String = "",
        noProxy: String = "",
        usesAuthentication: Bool = false,
        username: String = "",
        password: String = "",
    ) {
        self.mode = mode
        self.type = type
        self.host = host
        self.port = port
        self.noProxy = noProxy
        self.usesAuthentication = usesAuthentication
        self.username = username
        self.password = password
    }

    public static let empty = BrewProxySettings()

    /// Which text field a validation failure belongs to.
    public enum Field: String, CaseIterable, Sendable {
        case host
        case port
        case noProxy
        case username
        case password
    }

    /// Typed validation outcome. Copy lives in the presentation layer; this only says what is wrong.
    public enum ValidationError: Error, Equatable, Sendable {
        case newlineInValue(field: Field)
        case invalidHost
        case missingHost
        case invalidPort
        case missingUsername
    }

    public func validate() -> [ValidationError] {
        var failures: [ValidationError] = []
        for field in Field.allCases {
            let value = self[field]
            if value.contains("\n") || value.contains("\r") {
                failures.append(.newlineInValue(field: field))
            }
        }
        guard mode == .manual else {
            return failures
        }
        if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.missingHost)
        } else if !Self.isValidHost(host) {
            failures.append(.invalidHost)
        }
        if !Self.isValidPort(port) {
            failures.append(.invalidPort)
        }
        if usesAuthentication, username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.missingUsername)
        }
        return failures
    }

    public static func isValidPort(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.utf8.allSatisfy({ (48 ... 57).contains($0) }),
              let number = Int(trimmed)
        else {
            return false
        }
        return (1 ... 65535).contains(number)
    }

    /// Composed proxy URL for the current manual entry, or nil when mode is `none`.
    public var composedURL: String? {
        guard mode == .manual else {
            return nil
        }
        let defaultScheme = type == .socks ? "socks5" : "http"
        let scheme = originalScheme.flatMap { Self.proxyType(forScheme: $0) == type ? $0 : nil } ?? defaultScheme
        var authority = ""
        if usesAuthentication {
            let user = Self.encodedCredential(username.trimmingCharacters(in: .whitespaces))
            let pass = Self.encodedCredential(password)
            authority = pass.isEmpty ? "\(user)@" : "\(user):\(pass)@"
        }
        let hostname = Self.bracketedHost(host)
        let portValue = port.trimmingCharacters(in: .whitespaces)
        return "\(scheme)://\(authority)\(hostname):\(portValue)"
    }

    private static func bracketedHost(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.contains(":") && !trimmed.hasPrefix("[") ? "[\(trimmed)]" : trimmed
    }

    private static func isValidHost(_ value: String) -> Bool {
        let host = value.trimmingCharacters(in: .whitespaces)
        let forbidden = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "/\\@?#%"))
        guard host.rangeOfCharacter(from: forbidden) == nil,
              let components = URLComponents(string: "http://\(bracketedHost(host)):1"),
              components.host != nil, components.url != nil
        else {
            return false
        }
        return true
    }

    private static func encodedCredential(_ value: String) -> String {
        value.utf8.map { byte in
            switch byte {
            case 45, 46, 48 ... 57, 65 ... 90, 95, 97 ... 122, 126:
                String(UnicodeScalar(byte))
            default:
                String(format: "%%%02X", byte)
            }
        }.joined()
    }

    public subscript(field: Field) -> String {
        get {
            switch field {
            case .host: host
            case .port: port
            case .noProxy: noProxy
            case .username: username
            case .password: password
            }
        }
        set {
            switch field {
            case .host: host = newValue
            case .port: port = newValue
            case .noProxy: noProxy = newValue
            case .username: username = newValue
            case .password: password = newValue
            }
        }
    }
}

// MARK: - brew.env URL mapping

public extension BrewProxySettings {
    /// Parses `scheme://[user[:password]@]host:port` back into a manual entry.
    /// Returns nil when the value is not a usable proxy URL.
    static func parsing(proxyURL value: String) -> BrewProxySettings? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let schemeEnd = trimmed.range(of: "://"),
              let type = proxyType(forScheme: String(trimmed[trimmed.startIndex ..< schemeEnd.lowerBound]))
        else {
            return nil
        }

        let remainder = String(trimmed[schemeEnd.upperBound...])
        let (credentials, hostAndPort) = splitAuthority(remainder)
        let (host, port) = splitHostPort(hostAndPort)
        guard !host.isEmpty else {
            return nil
        }

        var settings = BrewProxySettings(mode: .manual, type: type, host: host, port: port)
        let scheme = String(trimmed[trimmed.startIndex ..< schemeEnd.lowerBound]).lowercased()
        // Keep TLS and SOCKS DNS semantics when editing an existing proxy's other fields.
        if scheme != (type == .socks ? "socks5" : "http") {
            settings.originalScheme = scheme
        }
        if !credentials.isEmpty {
            settings.usesAuthentication = true
            if let colon = credentials.firstIndex(of: ":") {
                let user = String(credentials[credentials.startIndex ..< colon])
                settings.username = user.removingPercentEncoding ?? user
                let password = String(credentials[credentials.index(after: colon)...])
                settings.password = password.removingPercentEncoding ?? password
            } else {
                settings.username = credentials.removingPercentEncoding ?? credentials
            }
        }
        return settings
    }

    private static func proxyType(forScheme scheme: String) -> ProxyType? {
        switch scheme.lowercased() {
        case "http", "https": .http
        case "socks4", "socks4a", "socks5", "socks5h": .socks
        default: nil
        }
    }

    private static func splitAuthority(_ remainder: String) -> (credentials: String, hostAndPort: String) {
        guard let at = remainder.lastIndex(of: "@") else {
            return ("", remainder)
        }
        let credentials = String(remainder[remainder.startIndex ..< at])
        let hostAndPort = String(remainder[remainder.index(after: at)...])
        return (credentials, hostAndPort)
    }

    private static func splitHostPort(_ hostAndPort: String) -> (host: String, port: String) {
        let cleaned = hostAndPort.split(separator: "/").first.map(String.init) ?? hostAndPort
        guard let colon = cleaned.lastIndex(of: ":"),
              colon > cleaned.startIndex,
              let portNumber = Int(cleaned[cleaned.index(after: colon)...]),
              (1 ... 65535).contains(portNumber)
        else {
            return (cleaned, "")
        }
        return (String(cleaned[cleaned.startIndex ..< colon]), String(portNumber))
    }
}
