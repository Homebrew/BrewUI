//
//  FocusedValues+Console.swift
//  Brew
//

import BrewUIComponents
import SwiftUI

public extension FocusedValues {
    /// Per-window expand/collapse binding for the console. Published by ``MainWindowView`` via `focusedSceneValue`;
    /// consumed by ``ConsoleCommands`` so `⌘\`` toggles the active window's strip.
    @Entry var consoleExpanded: Binding<Bool>?
}
