//
//  BundledHelper.swift
//  Brew
//

import Foundation

/// Executables the app target copies into `Contents/Helpers`.
enum BundledHelper {
    static func url(named name: String, in bundle: Bundle = .main) -> URL {
        bundle.bundleURL
            .appendingPathComponent("Contents/Helpers", isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }
}
