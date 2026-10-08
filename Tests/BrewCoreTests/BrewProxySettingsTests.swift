//
//  BrewProxySettingsTests.swift
//  BrewCoreTests
//

import BrewCore
import Foundation
import Testing

struct BrewProxySettingsTests {
    @Test func `empty settings are valid and compose no URL`() {
        #expect(BrewProxySettings.empty.validate().isEmpty)
        #expect(BrewProxySettings.empty.composedURL == nil)
    }

    @Test func `manual http entry composes an http URL for both schemes`() {
        let settings = BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "127.0.0.1",
            port: "7890",
            noProxy: "localhost,127.0.0.1",
        )
        #expect(settings.validate().isEmpty)
        #expect(settings.composedURL == "http://127.0.0.1:7890")
    }

    @Test func `manual socks entry composes a socks5 URL`() {
        let settings = BrewProxySettings(
            mode: .manual,
            type: .socks,
            host: "127.0.0.1",
            port: "1080",
        )
        #expect(settings.composedURL == "socks5://127.0.0.1:1080")
    }

    @Test func `credentials are embedded in the composed URL`() {
        let settings = BrewProxySettings(
            mode: .manual,
            host: "proxy.example",
            port: "8443",
            usesAuthentication: true,
            username: "user",
            password: "pass",
        )
        #expect(settings.composedURL == "http://user:pass@proxy.example:8443")
    }

    @Test func `password may be omitted`() {
        let settings = BrewProxySettings(
            mode: .manual,
            host: "proxy.example",
            port: "8443",
            usesAuthentication: true,
            username: "user",
        )
        #expect(settings.composedURL == "http://user@proxy.example:8443")
    }

    @Test func `manual mode requires host and port`() {
        let failures = BrewProxySettings(mode: .manual).validate()
        #expect(failures.contains(.missingHost))
        #expect(failures.contains(.invalidPort))
    }

    @Test(arguments: ["0", "65536", "abc", "", "  ", "+7890"])
    func `invalid ports fail validation`(port: String) {
        let settings = BrewProxySettings(mode: .manual, host: "127.0.0.1", port: port)
        #expect(settings.validate().contains(.invalidPort))
    }

    @Test(arguments: ["1", "7890", "65535"])
    func `valid ports pass validation`(port: String) {
        let settings = BrewProxySettings(mode: .manual, host: "127.0.0.1", port: port)
        #expect(settings.validate().isEmpty)
    }

    @Test func `authentication requires a login`() {
        let settings = BrewProxySettings(
            mode: .manual,
            host: "127.0.0.1",
            port: "7890",
            usesAuthentication: true,
        )
        #expect(settings.validate().contains(.missingUsername))
    }

    @Test func `newlines are rejected`() {
        let settings = BrewProxySettings(mode: .manual, host: "a\nb", port: "1")
        #expect(settings.validate().contains(.newlineInValue(field: .host)))
    }

    @Test(arguments: BrewProxySettings.Field.allCases)
    func `removing proxy settings ignores hidden field contents`(field: BrewProxySettings.Field) {
        var settings = BrewProxySettings(mode: .none)
        settings[field] = "invalid\nvalue"

        #expect(settings.validate().isEmpty)
    }

    @Test func `none mode does not require host or port`() {
        let settings = BrewProxySettings(mode: .none, host: "", port: "")
        #expect(settings.validate().isEmpty)
    }

    @Test func `proxy URLs parse back into a manual entry`() {
        let parsed = BrewProxySettings.parsing(proxyURL: "http://user:pass@127.0.0.1:7890")
        #expect(parsed == BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "127.0.0.1",
            port: "7890",
            usesAuthentication: true,
            username: "user",
            password: "pass",
        ))
    }

    @Test(arguments: ["socks5://127.0.0.1:1080", "socks5h://127.0.0.1:1080", "socks4://127.0.0.1:1080"])
    func `socks schemes map to the socks type`(value: String) {
        #expect(BrewProxySettings.parsing(proxyURL: value)?.type == .socks)
    }

    @Test(arguments: ["", "127.0.0.1:7890", "ftp://example.com:21", "http://", "not a url", "file:///tmp"])
    func `unusable proxy URLs parse to nil`(value: String) {
        #expect(BrewProxySettings.parsing(proxyURL: value) == nil)
    }

    @Test func `composed URL round trips through parsing`() throws {
        let settings = BrewProxySettings(
            mode: .manual,
            type: .socks,
            host: "proxy.example",
            port: "1080",
            usesAuthentication: true,
            username: "u",
            password: "p",
        )
        let composed = try #require(settings.composedURL)
        let parsed = try #require(BrewProxySettings.parsing(proxyURL: composed))
        #expect(parsed.type == .socks)
        #expect(parsed.host == "proxy.example")
        #expect(parsed.port == "1080")
        #expect(parsed.username == "u")
        #expect(parsed.password == "p")
    }

    @Test func `reserved credential characters are encoded and round trip`() throws {
        let settings = BrewProxySettings(
            mode: .manual,
            host: "localhost",
            port: "7890",
            usesAuthentication: true,
            username: "user:name@company",
            password: "a#b/c%40d\\e ",
        )

        #expect(settings.composedURL == "http://user%3Aname%40company:a%23b%2Fc%2540d%5Ce%20@localhost:7890")
        let url = try #require(settings.composedURL)
        #expect(BrewProxySettings.parsing(proxyURL: url) == settings)
    }

    @Test(arguments: ["http://proxy.example", "proxy.example/path", "user@proxy.example", "proxy example"])
    func `hosts cannot introduce URL components`(host: String) {
        let settings = BrewProxySettings(mode: .manual, host: host, port: "7890")
        #expect(!settings.validate().isEmpty)
    }

    @Test(arguments: ["https://proxy.example:8443", "socks4://proxy.example:1080", "socks4a://proxy.example:1080", "socks5h://proxy.example:1080"])
    func `reading and saving preserves the proxy protocol`(value: String) throws {
        let parsed = try #require(BrewProxySettings.parsing(proxyURL: value))
        #expect(parsed.composedURL == value)
    }

    @Test func `IPv6 hosts compose a bracketed authority`() {
        let settings = BrewProxySettings(mode: .manual, host: "::1", port: "7890")
        #expect(settings.validate().isEmpty)
        #expect(settings.composedURL == "http://[::1]:7890")
    }
}
