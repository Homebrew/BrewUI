//
//  DebugCrash.swift
//  Brew
//

import Foundation

#if DEBUG
    /// The crash kinds the debug menu can provoke, one per fault class macOS reports separately.
    ///
    /// Raising an `NSException` on the main thread is not enough to crash: AppKit catches
    /// exceptions thrown inside its event dispatch and, with `NSApplicationCrashOnExceptions`
    /// unset, logs them and carries on, so a menu item that raises one can leave the app running.
    /// Every kind here instead raises a signal or traps, which no `@catch` can intercept, and the
    /// exception case is raised on a thread with no handler above it.
    enum DebugCrash: CaseIterable {
        case abort
        case breakpointTrap
        case fatalError
        case boundsCheck
        case uncaughtException
        case badMemoryAccess
        case stackOverflowMainThread
        case stackOverflowBackgroundThread

        /// Names the fault and the signal the report will carry, so a report can be matched to the
        /// item that produced it.
        var title: String {
            switch self {
            case .abort: "Abort (SIGABRT)"
            case .breakpointTrap: "Breakpoint Trap (SIGTRAP)"
            case .fatalError: "Swift Fatal Error (SIGTRAP)"
            case .boundsCheck: "Swift Bounds Check (SIGTRAP)"
            case .uncaughtException: "Uncaught Exception (SIGABRT)"
            case .badMemoryAccess: "Bad Memory Access (SIGSEGV)"
            case .stackOverflowMainThread: "Stack Overflow, Main Thread (SIGSEGV)"
            case .stackOverflowBackgroundThread: "Stack Overflow, Background Thread (SIGBUS)"
            }
        }

        func crash() {
            switch self {
            case .abort:
                Foundation.abort()
            case .breakpointTrap:
                raise(SIGTRAP)
            case .fatalError:
                Swift.fatalError("Debug menu: forced fatalError")
            case .boundsCheck:
                var numbers = [0]
                // Computed so the bounds check happens at run time rather than at compile time.
                numbers[numbers.count + 6] = 0
            case .uncaughtException:
                Thread.detachNewThread {
                    NSException(
                        name: .genericException,
                        reason: "Debug menu: forced NSException",
                        userInfo: nil,
                    ).raise()
                }
            case .badMemoryAccess:
                UnsafeMutableRawPointer(bitPattern: 0x1)?.storeBytes(of: UInt8(0), as: UInt8.self)
            case .stackOverflowMainThread:
                _ = Self.recurse(0)
            case .stackOverflowBackgroundThread:
                // The same fault off the main thread, which macOS reports as SIGBUS against a
                // non-zero faulting thread rather than the SIGSEGV a main-thread overflow gives.
                Thread.detachNewThread { _ = Self.recurse(0) }
            }
        }

        /// Uses the result of the recursive call, so the recursion cannot become a loop.
        /// `nonisolated` so the background-thread case can run it off the main actor.
        @inline(never)
        private nonisolated static func recurse(_ depth: Int) -> Int {
            // The stack runs out long before the bound does. It is here because the target builds
            // with -warnings-as-errors, which rejects recursion with no exit at all.
            guard depth < .max else { return depth }
            return recurse(depth + 1) + depth
        }
    }
#endif
