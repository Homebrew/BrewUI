//
//  JobScope.swift
//  Brew
//

import Foundation

/// What a console job targets — used to filter jobs per detail pane vs. show globally in the console.
enum JobScope: Equatable {
    /// Operations targeting a single Homebrew package (install/uninstall/upgrade of one formula or cask).
    case package(name: String)

    /// Operations with no single package target (`brew update`, `brew doctor`, `brew cleanup`).
    case global

    /// Operations targeting multiple packages in one invocation (`brew upgrade a b c`).
    case batch(names: [String])
}
