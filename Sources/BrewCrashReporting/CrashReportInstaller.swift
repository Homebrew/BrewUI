//
//  CrashReportInstaller.swift
//  Brew
//

import Darwin
import Foundation

/// Installs process-wide crash capture: an uncaught-Objective-C-exception
/// handler and POSIX signal handlers for the common fatal signals. When either
/// fires, a report is written to the ``CrashReportStore`` so it can be shown on
/// the next launch.
///
/// This is intentionally *basic* crash handling. The signal path is written to
/// respect async-signal-safety as far as is practical from Swift: the file path
/// and header are materialised up-front (at install time), and at crash time we
/// only `open`/`write`/`backtrace_symbols_fd`/`close`, then restore the default
/// handler and re-raise so the OS still records its own crash report. Building
/// Swift strings inside a signal handler is unsafe, so the signal path never
/// does — it writes a pre-built C string header and static literals only.
public enum CrashReportInstaller {
    /// Fatal signals we install handlers for. `SIGABRT` covers Swift runtime
    /// traps and failed assertions; the rest are hardware/EXC faults.
    private static let handledSignals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]

    /// Installs the handlers. Safe to call once, early in app launch.
    ///
    /// - Parameters:
    ///   - store: where reports are written.
    ///   - environment: build/OS details baked into every report.
    ///   - date: capture time for the signal-path file (defaults to now); the
    ///     signal handler cannot compute a timestamp safely, so it is fixed here.
    public static func install(
        store: CrashReportStore,
        environment: CrashReportEnvironment,
        date: Date = Date(),
    ) {
        try? store.ensureDirectoryExists()

        // Pre-materialise everything the signal handler needs. `strdup` heap
        // allocations happen here, at install time — never inside the handler.
        let path = store.reportFileURL(for: date).path
        signalReportPath = strdup(path)
        signalReportHeader = strdup(CrashReportFormatter.signalReportHeader(
            environment: environment,
            date: date,
        ))

        // The uncaught-exception path runs in a near-normal context where
        // Foundation is safe, so it can build a richer report on the fly.
        exceptionStore = store
        exceptionEnvironment = environment

        NSSetUncaughtExceptionHandler(handleUncaughtException)

        for signalNumber in handledSignals {
            signal(signalNumber, handleFatalSignal)
        }
    }
}

// MARK: - Global handler state

//
// Signal handlers and `NSSetUncaughtExceptionHandler` take non-capturing
// C function pointers, so the context they need lives in module-global state.
// Synchronisation: each variable is written exactly once, during `install()` at
// launch, strictly before any handler can fire; thereafter it is read-only and
// only touched from the crashing thread. That write-once-then-read-only
// discipline is the external synchronisation that makes the unchecked
// annotation below sound.

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

    // Restore the default disposition and re-raise so the OS produces its own
    // crash report and the process terminates as it normally would.
    signal(signalNumber, SIG_DFL)
    raise(signalNumber)
}

/// Writes the signal's name using `StaticString`, whose bytes live in static
/// storage — no allocation, so this is safe inside a signal handler.
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

/// Dumps the current call stack straight to `fileDescriptor`.
/// `backtrace_symbols_fd` is documented as async-signal-safe, and the frame
/// buffer is stack-allocated to avoid touching the heap.
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

    let text = CrashReportFormatter.makeReportText(
        kind: "Uncaught exception \(exception.name.rawValue)",
        detail: exception.reason,
        callStack: exception.callStackSymbols,
        environment: environment,
        date: Date(),
    )
    _ = try? store.save(text: text, date: Date())
}
