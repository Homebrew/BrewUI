//
//  CrashReportInstallerTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Darwin
import Foundation
import Testing

private func makeTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CrashReportInstallerTests-\(UUID().uuidString)", isDirectory: true)
}

struct CrashReportInstallerTests {
    @Test func `handled signals include all fatal crash signals`() {
        let expected: Set<Int32> = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
        #expect(Set(CrashReportInstaller.handledSignals) == expected)
    }

    @Test func `restore default signal dispositions resets handled signals`() {
        var previousActions: [Int32: sigaction] = [:]
        for signalNumber in CrashReportInstaller.handledSignals {
            var action = sigaction()
            sigaction(signalNumber, nil, &action)
            previousActions[signalNumber] = action
        }
        defer {
            for (signalNumber, var action) in previousActions {
                sigaction(signalNumber, &action, nil)
            }
        }

        CrashReportInstaller.restoreDefaultSignalDispositions()

        for signalNumber in CrashReportInstaller.handledSignals {
            var action = sigaction()
            sigaction(signalNumber, nil, &action)
            #expect(action.__sigaction_u.__sa_handler == nil)
        }
    }

    @Test func `install registers custom handlers and prepares report directory`() {
        var previousActions: [Int32: sigaction] = [:]
        for signalNumber in CrashReportInstaller.handledSignals {
            var action = sigaction()
            sigaction(signalNumber, nil, &action)
            previousActions[signalNumber] = action
        }
        defer {
            for (signalNumber, var action) in previousActions {
                sigaction(signalNumber, &action, nil)
            }
        }

        let directory = makeTemporaryDirectory()
        let store = CrashReportStore(directoryURL: directory)
        let environment = CrashReportEnvironment(
            appVersion: "1.0",
            buildNumber: "1",
            osVersion: "macOS 15.0",
        )

        CrashReportInstaller.install(store: store, environment: environment)

        #expect(FileManager.default.fileExists(atPath: directory.path))

        for signalNumber in CrashReportInstaller.handledSignals {
            var action = sigaction()
            sigaction(signalNumber, nil, &action)
            #expect(action.__sigaction_u.__sa_handler != nil)
            #expect(action.sa_flags & SA_NODEFER != 0)
        }
    }
}
