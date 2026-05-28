//
//  FocusedValues+Console.swift
//  Brew
//

import BrewCore
import BrewDesignSystem
import BrewRepositories
import SwiftUI

extension FocusedValues {
    /// Per-window expand/collapse binding for the console. Published by ``MainWindowView`` via `focusedSceneValue`;
    /// consumed by ``ConsoleCommands`` so `⌘\`` toggles the active window's strip.
    @Entry var consoleExpanded: Binding<Bool>?
}
