//
//  DebugMenuCommands.swift
//  Brew
//

import Foundation
import SwiftUI

#if DEBUG
    struct DebugMenuCommands: Commands {
        @Bindable var selfUpgradeControl: SelfUpgradeDebugControl

        var body: some Commands {
            CommandMenu(Text(verbatim: "Debug")) {
                debugButton("Clear UserDefaults") {
                    UserDefaultsDebug.clearAll()
                }

                Divider()

                // Exercises the crash-reporting flow: the report appears on next launch.
                Menu {
                    debugButton("Fatal Error (signal)") {
                        fatalError("Debug menu: forced fatalError")
                    }
                    debugButton("Uncaught Exception") {
                        NSException(
                            name: .genericException,
                            reason: "Debug menu: forced NSException",
                            userInfo: nil,
                        ).raise()
                    }
                } label: {
                    Text(verbatim: "Force Crash")
                }

                Divider()

                Toggle(isOn: $selfUpgradeControl.simulateUpgradeAvailable) {
                    Text(verbatim: "Show the Self-Upgrade Banner")
                }
            }
        }

        private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
            Button(action: action) { Text(verbatim: title) }
        }
    }
#endif
