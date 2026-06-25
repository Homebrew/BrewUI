//
//  UserDefaultsDebug.swift
//  Brew
//

import Foundation

#if DEBUG
    enum UserDefaultsDebug {
        /// Removes all keys in the app’s standard `UserDefaults` persistent domain.
        static func clearAll(userDefaults: UserDefaults = .standard) {
            guard let domain = Bundle.main.bundleIdentifier else { return }
            userDefaults.removePersistentDomain(forName: domain)
        }
    }
#endif
