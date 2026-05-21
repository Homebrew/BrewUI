//
//  DebugMenuCommands.swift
//  Brew
//

import SwiftUI

#if DEBUG
    struct DebugMenuCommands: Commands {
        var body: some Commands {
            CommandMenu("Debug") {
                Button("Clear UserDefaults") {
                    UserDefaultsDebug.clearAll()
                }
            }
        }
    }
#endif
