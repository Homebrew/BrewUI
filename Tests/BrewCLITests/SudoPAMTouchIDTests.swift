//
//  SudoPAMTouchIDTests.swift
//  BrewCLITests
//

@testable import BrewCLI
import Foundation
import Testing

struct SudoPAMTouchIDTests {
    @Test func `an uncommented pam_tid line enables Touch ID`() throws {
        try withPAMConfiguration("""
        # uncomment following line to enable Touch ID for sudo
        auth       sufficient     pam_tid.so
        """) { url in
            #expect(SudoPAMTouchID.isEnabled(at: [url]))
        }
    }

    @Test func `a commented pam_tid line does not enable Touch ID`() throws {
        try withPAMConfiguration("""
        # sudo_local: local config file which survives system update and is included for sudo
        # uncomment following line to enable Touch ID for sudo
        #auth       sufficient     pam_tid.so
        # auth sufficient pam_tid.so
        auth       include        sudo_local
        auth       required       pam_tid.so
        """) { url in
            #expect(!SudoPAMTouchID.isEnabled(at: [url]))
        }
    }

    @Test func `a missing pam file does not enable Touch ID`() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("pam-missing-\(UUID().uuidString)")
        #expect(!SudoPAMTouchID.isEnabled(at: [missing]))
    }

    @Test func `an enabled line in a later file counts when an earlier file is missing`() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("pam-missing-\(UUID().uuidString)")
        try withPAMConfiguration("auth sufficient pam_tid.so\n") { enabled in
            #expect(SudoPAMTouchID.isEnabled(at: [missing, enabled]))
        }
    }
}

private func withPAMConfiguration(_ contents: String, _ body: (URL) -> Void) throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("pam-\(UUID().uuidString)")
    try contents.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    body(url)
}
