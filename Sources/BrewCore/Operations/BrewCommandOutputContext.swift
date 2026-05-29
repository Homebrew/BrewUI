//
//  BrewCommandOutputContext.swift
//  BrewCore
//

import Foundation

/// Task-local plumbing for streaming subprocess output without threading a sink through every command type.
///
/// ``BrewCommandCenter/submit(id:command:)`` implementations set ``sink`` for the duration of a submit;
/// `BrewCommandService` reads the value and forwards each `\n`-delimited line through it as the subprocess emits bytes.
/// Commands themselves remain unchanged — they still call `context.commandRunner.run(...)`.
public enum BrewCommandOutputContext {
    /// Per-task sink for subprocess output. `nil` when no console is observing — the runner falls back to the
    /// existing buffered-read path with no overhead.
    @TaskLocal public static var sink: (@Sendable (BrewCommandOutputLine) -> Void)?
}
