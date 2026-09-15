@testable import BrewLocalizeCore
import Foundation
import Testing

@Suite("CatalogLocation")
struct CatalogLocationTests {
    @Test
    func `package catalog maps to its target directory`() {
        let location = CatalogLocation(path: "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings")
        #expect(location.sourceDirectory == "Sources/BrewFeatureDoctor")
    }

    @Test
    func `app catalog maps to the Homebrew directory`() {
        let location = CatalogLocation(path: CatalogLocation.appCatalogPath)
        #expect(location.sourceDirectory == "Homebrew" && location.isApp)
    }

    @Test(arguments: [
        "Sources/BrewUIComponents/Resources/Localizable.xcstrings",
        "Sources/BrewFeatureInstalled/Resources/Localizable.xcstrings",
        CatalogLocation.appCatalogPath,
    ])
    func `UI targets are allowed to hold a catalog`(path: String) {
        #expect(CatalogLocation(path: path).isInAllowedLayer)
    }

    @Test(arguments: [
        "Sources/BrewCore/Resources/Localizable.xcstrings",
        "Sources/BrewRepositories/Resources/Localizable.xcstrings",
        "Sources/BrewRepositoryInterfaces/Resources/Localizable.xcstrings",
        "Sources/BrewFeatureDoctor/Localizable.xcstrings",
        "HomebrewUpgradeHelper/Localizable.xcstrings",
    ])
    func `non-UI targets and misplaced catalogs are rejected`(path: String) {
        #expect(!CatalogLocation(path: path).isInAllowedLayer)
    }

    @Test
    func `discovery finds catalogs under Sources and Homebrew only`() throws {
        let root = try TemporaryRepo.make(files: [
            "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings": "{}",
            "Sources/BrewFeatureDoctor/Views/DoctorView.swift": "",
            "Homebrew/Localizable.xcstrings": "{}",
            "Tests/Fixtures/Localizable.xcstrings": "{}",
        ])
        defer { root.remove() }
        let paths = CatalogLocation.discover(root: root.url).map(\.path)
        #expect(paths == ["Homebrew/Localizable.xcstrings", "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings"])
    }

    @Test
    func `source files are the Swift files under the target, sorted`() throws {
        let root = try TemporaryRepo.make(files: [
            "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings": "{}",
            "Sources/BrewFeatureDoctor/Views/DoctorView.swift": "",
            "Sources/BrewFeatureDoctor/ViewModels/DoctorViewModel.swift": "",
            "Sources/BrewFeatureDoctor/README.md": "",
            "Sources/BrewFeatureConfig/Views/ConfigView.swift": "",
        ])
        defer { root.remove() }
        let files = CatalogLocation(path: "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings")
            .sourceFiles(root: root.url)
        #expect(files == [
            "Sources/BrewFeatureDoctor/ViewModels/DoctorViewModel.swift",
            "Sources/BrewFeatureDoctor/Views/DoctorView.swift",
        ])
    }
}

struct TemporaryRepo {
    let url: URL

    static func make(files: [String: String]) throws -> TemporaryRepo {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("brew-localize-tests-\(UUID().uuidString)", isDirectory: true)
        for (path, contents) in files {
            let fileURL = url.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return TemporaryRepo(url: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
