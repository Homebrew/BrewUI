//
//  CommandOutput.swift
//  Brew
//

import Foundation

struct CommandOutput: Equatable {
    var standardOutput: String
    var standardError: String
    var terminationStatus: Int32
}
