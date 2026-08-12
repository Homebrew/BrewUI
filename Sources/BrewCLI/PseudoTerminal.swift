//
//  PseudoTerminal.swift
//  BrewCLI
//

import BrewCore
import Darwin
import Foundation
import System

/// A pty pair: the primary (POSIX: master) stays here, the replica (POSIX: slave) becomes the child's
/// stdout/stderr and is a real terminal device, so `isatty` holds in the child.
///
/// The replica must be closed in this process once the child is spawned. While any replica descriptor
/// stays open here the kernel sees a potential writer, so reads on the primary never report EOF.
// `read` deliberately touches `primaryFD` unlocked: it parks for as long as the child is quiet, and
// holding the lock across it would deadlock `closeReplica`.
// swiftlint:disable:next unchecked_sendable
final class PseudoTerminal: @unchecked Sendable {
    /// Non-zero because `openpty` defaults to 0x0, which some tools read as "not a real terminal" and
    /// use to suppress progress rendering.
    static let defaultColumns: UInt16 = 120
    static let defaultRows: UInt16 = 40

    private let lock = NSLock()
    private var primaryFD: Int32
    private var replicaFD: Int32
    private var isPrimaryClosed = false
    private var isReplicaClosed = false

    init(columns: UInt16 = PseudoTerminal.defaultColumns, rows: UInt16 = PseudoTerminal.defaultRows) throws {
        var primary: Int32 = -1
        var replica: Int32 = -1
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)

        let result = openpty(&primary, &replica, nil, nil, &size)
        // Captured before anything else: building the message allocates, and an allocation makes syscalls
        // that overwrite `errno`.
        let failureCode = errno
        guard result == 0 else {
            throw BrewCommandError.launchFailed(
                underlying: "openpty failed: \(String(cString: strerror(failureCode))) (\(failureCode))",
            )
        }

        primaryFD = primary
        replicaFD = replica
        Self.configureLineDiscipline(replica)
    }

    deinit {
        // The run path closes both explicitly; this catches a throw between allocation and spawn.
        if !isReplicaClosed { close(replicaFD) }
        if !isPrimaryClosed { close(primaryFD) }
    }

    var replicaDescriptor: FileDescriptor {
        lock.lock()
        defer { lock.unlock() }
        return FileDescriptor(rawValue: replicaFD)
    }

    /// Call immediately after the child is spawned; see the ownership note on the type. Idempotent.
    func closeReplica() {
        lock.lock()
        defer { lock.unlock() }
        guard !isReplicaClosed else {
            return
        }
        isReplicaClosed = true
        close(replicaFD)
    }

    /// Idempotent.
    func closePrimary() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPrimaryClosed else {
            return
        }
        isPrimaryClosed = true
        close(primaryFD)
    }

    enum ReadOutcome: Equatable {
        case data(Data)
        /// Nothing arrived within the timeout; the terminal is still open.
        case timedOut
        /// No writers remain.
        case endOfInput
    }

    /// The timeout exists because end-of-input is driven by descriptors, not process exit: a grandchild
    /// that inherited the replica holds the terminal open after `brew` exits, so an unbounded read would
    /// hang the drain until that straggler finished.
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
        // Both `0` and `-1`/`EIO` mean the last writer closed; `EIO` is the normal Darwin path.
        return .endOfInput
    }

    /// Clearing `OPOST` disables `ONLCR`, which would otherwise rewrite every `\n` as `\r\n` and leave a
    /// stray `\r` on every captured line. Carriage returns the child writes itself are unaffected, so
    /// progress redraws still arrive intact.
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
