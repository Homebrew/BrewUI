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

                // Shows the banner only: pressing Upgrade on a simulated update reports that nothing was
                // upgraded rather than running one against the copy installed in /Applications.
                Toggle("Show the Self-Update Banner", isOn: $selfUpdateControl.simulateUpdateAvailable)
            }
        }
    }
#endif
