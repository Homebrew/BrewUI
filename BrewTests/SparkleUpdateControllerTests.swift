//
//  SparkleUpdateControllerTests.swift
//  BrewTests
//

@testable import Homebrew
import Testing

@MainActor
struct SparkleUpdateControllerTests {
    @Test
    func `missing public key keeps updater disabled`() {
        #expect(!SparkleUpdateController.isConfigured(infoDictionary: [
            "SUFeedURL": "https://github.com/Homebrew/BrewUI/releases/latest/download/appcast.xml",
        ]))
    }

    @Test
    func `valid HTTPS feed and public key enable updater`() {
        #expect(SparkleUpdateController.isConfigured(infoDictionary: [
            "SUFeedURL": "https://updates.example.test/appcast.xml",
            "SUPublicEDKey": "public-ed25519-key",
        ]))
    }

    @Test(arguments: [
        "http://updates.example.test/appcast.xml",
        "https:///appcast.xml",
        "https://updates.example.test/appcast.xml ",
    ])
    func `invalid feed or blank key keeps updater disabled`(feed: String) {
        let publicKey = feed.hasSuffix(" ") ? " \n" : "public-ed25519-key"
        #expect(!SparkleUpdateController.isConfigured(infoDictionary: [
            "SUFeedURL": feed,
            "SUPublicEDKey": publicKey,
        ]))
    }
}
