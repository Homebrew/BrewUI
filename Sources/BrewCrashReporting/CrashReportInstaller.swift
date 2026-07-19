//
//  CrashReportInstaller.swift
//  Brew
//

import Darwin
import Foundation

/// Installs process-wide crash capture — an uncaught-exception handler plus
/// POSIX signal handlers — that writes a report to the ``CrashReportStore`` for
/// display on the next launch.
///
/// The signal path is async-signal-safe: everything it needs (file path,
/// header) is materialised at install time, and at crash time it only does
/// `open`/`write`/`backtrace_symbols_fd`/`close` before re-raising so the OS
/// still records its own report. It never builds Swift strings.
public enum CrashReportInstaller {
    private static let handledSignals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]

    /// Call once, early in launch. `date` is fixed here because the signal
    /// handler cannot compute a timestamp safely.
    public static func install(
        store: CrashReportStore,
        environment: CrashReportEnvironment,
        date: Date = Date(),
    ) {
        try? store.ensureDirectoryExists()

        // Everything the signal handler touches is allocated here, at install
        // time, so the handler itself never reaches for the heap.
        let path = store.reportFileURL(for: date).path
        signalReportPath = strdup(path)

        let header = CrashReportFormatter.signalReportHeader(environment: environment, date: date)
        signalReportHeader = strdup(header)
        signalReportHeaderLength = header.utf8.count

        signalFrameBuffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(
            capacity: signalFrameCapacity,
        )

        // The exception path runs in a near-normal context, so it builds its report on the fly.
        exceptionStore = store
        exceptionEnvironment = environment

        NSSetUncaughtExceptionHandler(handleUncaughtException)

        // `SA_RESETHAND` restores the default disposition before the handler
        // runs (so the re-raise below terminates the process); `SA_NODEFER`
        // lets that re-raise deliver synchronously rather than being blocked.
        var action = sigaction()
        action.__sigaction_u.__sa_handler = handleFatalSignal
        action.sa_flags = SA_RESETHAND | SA_NODEFER
        sigemptyset(&action.sa_mask)
        for signalNumber in handledSignals {
            sigaction(signalNumber, &action, nil)
        }
    }
}

// MARK: - Global handler state

// C function-pointer handlers can't capture context, so it lives in module globals.
// Each is written exactly once during `install()`, before any handler can fire, then
// read-only — that discipline is what makes the unchecked annotation below sound.

// swiftlint:disable:next nonisolated_unsafe
private nonisolated(unsafe) var signalReportPath: UnsafeMutablePointer<CChar>?
// swiftlint:disable:next nonisolated_unsafe
private nonisolated(unsafe) var signalReportHeader: UnsafeMutablePointer<CChar>?
// The header's byte length, computed at install time so the handler avoids `strlen`.
// swiftlint:disable:next nonisolated_unsafe
private nonisolated(unsafe) var signalReportHeaderLength = 0
/// Backtrace frame buffer, allocated once at install time so the handler never calls `malloc`.
private let signalFrameCapacity = 128
// swiftlint:disable:next nonisolated_unsafe
private nonisolated(unsafe) var signalFrameBuffer: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
// swiftlint:disable:next nonisolated_unsafe
private nonisolated(unsafe) var exceptionStore: CrashReportStore?
// swiftlint:disable:next nonisolated_unsafe
private nonisolated(unsafe) var exceptionEnvironment: CrashReportEnvironment?

// MARK: - Signal path (async-signal-safe)

private let handleFatalSignal: @convention(c) (Int32) -> Void = { signalNumber in
    if let path = signalReportPath {
        let fileDescriptor = open(path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        if fileDescriptor >= 0 {
            if let header = signalReportHeader {
                _ = write(fileDescriptor, header, signalReportHeaderLength)
            }
            writeSignalName(fileDescriptor, signalNumber)
            writeBacktrace(to: fileDescriptor)
            close(fileDescriptor)
        }
    }

    // `SA_RESETHAND` has already restored the default disposition; re-raise so
    // the OS records its own report and the process terminates.
    raise(signalNumber)
}

/// `StaticString` bytes live in static storage, so writing them allocates nothing.
private func writeSignalName(_ fileDescriptor: Int32, _ signalNumber: Int32) {
    let name: StaticString = switch signalNumber {
    case SIGABRT: "Signal: SIGABRT\n"
    case SIGBUS: "Signal: SIGBUS\n"
    case SIGFPE: "Signal: SIGFPE\n"
    case SIGILL: "Signal: SIGILL\n"
    case SIGSEGV: "Signal: SIGSEGV\n"
    case SIGTRAP: "Signal: SIGTRAP\n"
    default: "Signal: unknown\n"
    }
    name.withUTF8Buffer { buffer in
        _ = write(fileDescriptor, buffer.baseAddress, buffer.count)
    }
}

/// `backtrace_symbols_fd` is async-signal-safe; it writes into the buffer that
/// was pre-allocated at install time, so nothing here touches the heap.
private func writeBacktrace(to fileDescriptor: Int32) {
    guard let buffer = signalFrameBuffer else {
        return
    }
    let frameCount = backtrace(buffer, Int32(signalFrameCapacity))
    backtrace_symbols_fd(buffer, frameCount, fileDescriptor)
}

// MARK: - Uncaught-exception path

private let handleUncaughtException: @convention(c) (NSException) -> Void = { exception in
    guard let store = exceptionStore, let environment = exceptionEnvironment else {
        return
    }

    let date = Date()
    let text = CrashReportFormatter.makeReportText(
        kind: "Uncaught exception \(exception.name.rawValue)",
        detail: exception.reason,
        callStack: exception.callStackSymbols,
        environment: environment,
        date: date,
    )
    _ = try? store.save(text: text, date: date)
}
