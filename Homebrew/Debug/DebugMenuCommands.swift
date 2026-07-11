//
//  DebugMenuCommands.swift
//  Brew
//

import Foundation
import SwiftUI

#if DEBUG
    struct DebugMenuCommands: Commands {
        var body: some Commands {
            CommandMenu("Debug") {
                Button("Clear UserDefaults") {
                    UserDefaultsDebug.clearAll()
                }

                Divider()

                // Deliberately crash the app so the crash-reporting flow can be
                // exercised: the report should appear on the next launch. These
                // exist only in DEBUG builds.
                Menu("Force Crash") {
                    Button("Fatal Error (signal)") {
                        fatalError("Debug menu: forced fatalError")
                    }
                    Button("Uncaught Exception") {
                        NSException(
                            name: .genericException,
                            reason: "Debug menu: forced NSException",
                            userInfo: nil,
                        ).raise()
                    }
                }
            }
        }
    }
#endif
