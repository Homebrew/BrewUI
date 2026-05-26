//
//  UserDefaultsTestSupport.swift
//  BrewTests
//

import Foundation

extension UserDefaults {
    /// Removes every key in `UserDefaults.standard` (or whichever instance) that starts with
    /// the given prefix. Used by tests that isolate state with a per-test prefix instead of a
    /// suite name, so cleanup doesn't depend on `removePersistentDomain`.
    func removePersistedKeys(withPrefix prefix: String) {
        for key in dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            removeObject(forKey: key)
        }
    }
}
