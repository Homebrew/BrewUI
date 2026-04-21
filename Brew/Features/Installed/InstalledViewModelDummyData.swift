//
//  InstalledViewModelDummyData.swift
//  Brew
//
//  Lives in its own file so arrays are not inferred `@MainActor` when used as default
//  parameters on `InstalledViewModel.init` (Swift 6 concurrency).
//

import Foundation

enum InstalledViewModelDummyData {
    static let formulae: [InstalledPackageRow] = [
        InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "Distributed revision control system",
            installedVersion: "v2.45.0",
            updateVersion: "v2.45.1",
        ),
        InstalledPackageRow(
            name: "Node",
            kind: .formula,
            description: "Platform built on Chrome's JavaScript runtime",
            installedVersion: "v22.14.0",
        ),
        InstalledPackageRow(
            name: "Python",
            kind: .formula,
            description: "Interpreted, interactive, object-oriented programming language",
            installedVersion: "v3.13.2",
        ),
    ]

    static let casks: [InstalledPackageRow] = [
        InstalledPackageRow(
            name: "Visual Studio Code",
            kind: .cask,
            description: "Code editing redefined",
            installedVersion: "v1.99.0",
        ),
        InstalledPackageRow(
            name: "Docker",
            kind: .cask,
            description: "App to build and share containerized applications",
            installedVersion: "v4.39.0",
        ),
    ]
}
