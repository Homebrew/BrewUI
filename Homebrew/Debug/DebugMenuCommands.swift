//
//  DebugMenuCommands.swift
//  Brew
//

import Foundation
import SwiftUI

#if DEBUG
    struct DebugMenuCommands: Commands {
        @Bindable var selfUpdateControl: SelfUpdateDebugControl

        var body: some Commands {
            CommandMenu("Debug") {
                Button("Clear UserDefaults") {
                    UserDefaultsDebug.clearAll()
                }

                Divider()

                // Exercises the crash-reporting flow: the report appears on next launch.
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

                Divider()

                Toggle("Simulate Homebrew Update Available", isOn: $selfUpdateControl.simulateUpdateAvailable)
                Toggle("Simulate a Newer Version (test “Later” re-show)", isOn: $selfUpdateControl.simulateNewerVersion)
                // The quit, the helper and the relaunch are all real; only `brew upgrade --cask` is skipped,
                // which a dev build has no business running against the installed app.
                Toggle("Skip the Real Upgrade (still quits and relaunches)", isOn: $selfUpdateControl.simulateUpdateHandoff)
            }
        }
    }
#endif
