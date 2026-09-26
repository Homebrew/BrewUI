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
                    ForEach(DebugCrash.allCases, id: \.self) { crash in
                        debugButton(crash.title) { crash.crash() }
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
