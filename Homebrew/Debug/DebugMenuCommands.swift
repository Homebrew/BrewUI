//
//  DebugMenuCommands.swift
//  Brew
//

import BrewUIComponents
import Foundation
import SwiftUI

#if DEBUG
    struct DebugMenuCommands: Commands {
        @Bindable var selfUpgradeControl: SelfUpgradeDebugControl

        let localization: AppLocalization

        var body: some Commands {
            CommandMenu(localization.string("Debug")) {
                Button(localization.string("Clear UserDefaults")) {
                    UserDefaultsDebug.clearAll()
                }

                Divider()

                // Exercises the crash-reporting flow: the report appears on next launch.
                Menu(localization.string("Force Crash")) {
                    Button(localization.string("Fatal Error (signal)")) {
                        fatalError("Debug menu: forced fatalError")
                    }
                    Button(localization.string("Uncaught Exception")) {
                        NSException(
                            name: .genericException,
                            reason: "Debug menu: forced NSException",
                            userInfo: nil,
                        ).raise()
                    }
                }

                Divider()

                Toggle(localization.string("Show the Self-Upgrade Banner"), isOn: $selfUpgradeControl.simulateUpgradeAvailable)
            }
        }
    }
#endif
