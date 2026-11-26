//
//  DebugMenuCommands.swift
//  Brew
//

import SwiftUI

#if DEBUG
    struct DebugMenuCommands: Commands {
        @Bindable var selfUpgradeControl: SelfUpgradeDebugControl

        var body: some Commands {
            CommandMenu(Text(verbatim: "Debug")) {
                Button {
                    UserDefaultsDebug.clearAll()
                } label: {
                    Text(verbatim: "Clear UserDefaults")
                }

                Divider()

                Toggle(isOn: $selfUpgradeControl.simulateUpgradeAvailable) {
                    Text(verbatim: "Show the Self-Upgrade Banner")
                }
            }
        }
    }
#endif
