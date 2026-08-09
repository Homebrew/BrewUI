//
//  PseudoTerminal.swift
//  BrewCLI
//

import BrewCore
import Darwin
import Foundation
import System

/// An allocated pseudo-terminal pair, used to give `brew` a real terminal on stdout/stderr.
///
/// A pty is two file descriptors onto one kernel terminal device: the **primary** (POSIX: master), which
/// this process holds and reads the child's output from, and the **replica** (POSIX: slave), which becomes
/// the child's stdout/stderr. The replica *is* a terminal device, so `isatty(1)` is true in the child —
/// that is the whole point. Homebrew then emits colour and progress rendering on its own, and the libc
/// in every tool `brew` shells out to switches from block buffering to line buffering, so output arrives
/// as it is produced rather than in 4–8 KB bursts.
///
/// Ownership rules that matter (both are easy to get wrong and both hang or crash if you do):
///   - The replica must be closed in *this* process once the child has been spawned. While any replica
///     descriptor stays open here, the kernel sees a potential writer and reads on the primary never
///     report EOF — the drain would block forever after the child exits.
///   - Reads on the primary can report end-of-input as either `0` or `-1`/`EIO` depending on ordering.
///     Both mean "no writers left". ``read()`` normalises them.
// The three descriptor fields are the only mutable state, and every access to them goes through `lock`.
// `read` touches `primaryFD` without the lock deliberately: it blocks for as long as the child is quiet,
// so holding the lock across it would deadlock `closeReplica` — the fd is stable for the read's lifetime
// because only the drain calls `closePrimary`, and only after `read` has returned nil.
// swiftlint:disable:next unchecked_sendable
final class PseudoTerminal: @unchecked Sendable {
    /// Terminal size reported to the child via `TIOCGWINSZ`. `openpty` would otherwise leave this at 0×0,
    /// which some tools read as "not a real terminal" and use to suppress progress rendering entirely.
    static let defaultColumns: UInt16 = 120
    static let defaultRows: UInt16 = 40

    private let lock = NSLock()
    private var primaryFD: Int32
    private var replicaFD: Int32
    private var isPrimaryClosed = false
    private var isReplicaClosed = false

    /// Allocates the pair and configures the line discipline. Throws if the kernel cannot provide a pty.
    init(columns: UInt16 = PseudoTerminal.defaultColumns, rows: UInt16 = PseudoTerminal.defaultRows) throws {
        var primary: Int32 = -1
        var replica: Int32 = -1
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)

        guard openpty(&primary, &replica, nil, nil, &size) == 0 else {
            throw BrewCommandError.launchFailed(
                underlying: "openpty failed: \(String(cString: strerror(errno)))",
            )
        }

        primaryFD = primary
        replicaFD = replica
        Self.configureLineDiscipline(replica)
    }

    deinit {
        // Belt and braces: the run path closes both explicitly, but an early `throw` between allocation
        // and spawn would otherwise leak a pair.
        if !isReplicaClosed { close(replicaFD) }
        if !isPrimaryClosed { close(primaryFD) }
    }

    /// The child's end of the pair, to be handed to `Subprocess` as stdout/stderr.
    var replicaDescriptor: FileDescriptor {
        lock.lock()
        defer { lock.unlock() }
        return FileDescriptor(rawValue: replicaFD)
    }

    /// Closes this process's copy of the replica. Call once, immediately after the child is spawned —
    /// see the ownership note on the type. Idempotent.
    func closeReplica() {
        lock.lock()
        defer { lock.unlock() }
        guard !isReplicaClosed else {
            return
        }
        isReplicaClosed = true
        close(replicaFD)
    }

    /// Closes the primary. Idempotent; safe to call after ``closeReplica()``.
    func closePrimary() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPrimaryClosed else {
            return
        }
        isPrimaryClosed = true
        close(primaryFD)
    }

    /// The result of one bounded read from the primary.
    enum ReadOutcome: Equatable {
        /// Bytes were read.
        case data(Data)
        /// Nothing arrived within the timeout. The terminal is still open.
        case timedOut
        /// No writers remain: the child and everything it spawned have closed their end.
        case endOfInput
    }

    /// One read from the primary, waiting at most `timeout` for bytes to arrive.
    ///
    /// The timeout exists because end-of-input is driven by *descriptors*, not by process exit: any
    /// grandchild that inherited the replica (a `curl`, a cask's installer) holds the terminal open after
    /// `brew` itself exits. An unbounded read would hang the drain — and with it the console job — until
    /// that straggler happened to finish. Returning ``ReadOutcome/timedOut`` lets the caller notice the
    /// child is gone and stop on its own terms.
    func read(timeout: Duration = .milliseconds(100)) -> ReadOutcome {
        var descriptor = pollfd(fd: primaryFD, events: Int16(POLLIN), revents: 0)
        let milliseconds = Int32(clamping: timeout.components.seconds * 1000
            + Int64(timeout.components.attoseconds / 1_000_000_000_000_000))

        let ready = poll(&descriptor, 1, milliseconds)
        if ready == 0 {
            return .timedOut
        }
        if ready < 0 {
            return errno == EINTR ? .timedOut : .endOfInput
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = buffer.withUnsafeMutableBytes { raw -> Int in
            guard let base = raw.baseAddress else {
                return 0
            }
            return Darwin.read(primaryFD, base, raw.count)
        }

        if bytesRead > 0 {
            return .data(Data(buffer[0 ..< bytesRead]))
        }
        if bytesRead < 0, errno == EINTR || errno == EAGAIN {
            return .timedOut
        }
        // Both `0` and `-1`/`EIO` mean the last writer closed; `EIO` is the normal Darwin path here.
        return .endOfInput
    }

    /// Puts the replica into a mode that hands back exactly the bytes the child wrote.
    ///
    /// `OPOST` is cleared, which disables the output post-processing the kernel would otherwise apply —
    /// most relevantly `ONLCR`, which rewrites every `\n` into `\r\n`. Leaving it on would put a stray
    /// `\r` at the end of every captured line, which the console would render and the doctor parser would
    /// have to strip. Clearing it does **not** affect carriage returns the child emits deliberately, so
    /// progress-bar redraws still arrive intact — exactly the distinction we want.
    ///
    /// Echo is cleared because nothing in this app writes to the child's input; if that ever changes,
    /// echo would otherwise reflect the written bytes straight back into the captured output.
    private static func configureLineDiscipline(_ replica: Int32) {
        var settings = termios()
        guard tcgetattr(replica, &settings) == 0 else {
            return
        }
        settings.c_oflag &= ~tcflag_t(OPOST)
        settings.c_lflag &= ~tcflag_t(ECHO | ECHOE | ECHOK | ECHONL)
        _ = tcsetattr(replica, TCSANOW, &settings)
    }
}
