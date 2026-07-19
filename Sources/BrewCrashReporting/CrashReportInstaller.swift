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

        // `strdup` heap allocations happen here so the signal handler never touches the heap.
        let path = store.reportFileURL(for: date).path
        signalReportPath = strdup(path)
        signalReportHeader = strdup(CrashReportFormatter.signalReportHeader(
            environment: environment,
            date: date,
        ))

        // The exception path runs in a near-normal context, so it builds its report on the fly.
        exceptionStore = store
        exceptionEnvironment = environment

        NSSetUncaughtExceptionHandler(handleUncaughtException)

        for signalNumber in handledSignals {
            signal(signalNumber, handleFatalSignal)
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
                _ = write(fileDescriptor, header, strlen(header))
            }
            writeSignalName(fileDescriptor, signalNumber)
            writeBacktrace(to: fileDescriptor)
            close(fileDescriptor)
        }
    }

    // Re-raise under the default handler so the OS records its own report and terminates.
    signal(signalNumber, SIG_DFL)
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

/// `backtrace_symbols_fd` is async-signal-safe; the frame buffer is stack-allocated
/// to keep off the heap.
private func writeBacktrace(to fileDescriptor: Int32) {
    let maxFrames = 128
    withUnsafeTemporaryAllocation(
        of: UnsafeMutableRawPointer?.self,
        capacity: maxFrames,
    ) { buffer in
        let frameCount = backtrace(buffer.baseAddress, Int32(maxFrames))
        backtrace_symbols_fd(buffer.baseAddress, frameCount, fileDescriptor)
    }
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
