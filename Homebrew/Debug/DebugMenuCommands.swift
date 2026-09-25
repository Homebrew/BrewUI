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
            CommandMenu(Text("Debug", bundle: #bundle, comment: "Developer debug menu title")) {
                debugButton(LocalizedStringResource("Clear UserDefaults", bundle: #bundle, comment: "Debug menu: clear saved app preferences")) {
                    UserDefaultsDebug.clearAll()
                }

                Divider()

                // Exercises the crash-reporting flow: the report appears on next launch.
                Menu {
                    debugButton(LocalizedStringResource("Fatal Error (signal)", bundle: #bundle, comment: "Debug crash test: trigger a fatal error signal")) {
                        fatalError("Debug menu: forced fatalError")
                    }
                    debugButton(LocalizedStringResource("Uncaught Exception", bundle: #bundle, comment: "Debug crash test: raise an uncaught exception")) {
                        NSException(
                            name: .genericException,
                            reason: "Debug menu: forced NSException",
                            userInfo: nil,
                        ).raise()
                    }
                } label: {
                    Text("Force Crash", bundle: #bundle, comment: "Debug submenu: deliberately crash the app to test reporting")
                }

                Divider()

                Toggle(isOn: $selfUpgradeControl.simulateUpgradeAvailable) {
                    Text("Show the Self-Upgrade Banner", bundle: #bundle, comment: "Debug toggle: preview the app self-upgrade banner")
                }
            }
        }

        private func debugButton(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
            Button(action: action) { Text(title) }
        }
    }
#endif
