//
//  CommandOutput.swift
//  Brew
//

import Foundation

nonisolated struct CommandOutput: Equatable {
    var standardOutput: String
    var standardError: String
    var terminationStatus: Int32
}
