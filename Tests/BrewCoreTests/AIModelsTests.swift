//
//  AIModelsTests.swift
//  BrewCoreTests
//

import BrewCore
import Foundation
import Testing

@Suite("AIModels")
struct AIModelsTests {
    @Test func `model catalog provides curated models with valid URLs`() {
        #expect(!AIModelCatalog.allModels.isEmpty)
        for model in AIModelCatalog.allModels {
            #expect(!model.id.isEmpty)
            #expect(!model.name.isEmpty)
            #expect(model.downloadSizeMB > 0)
            #expect(model.requiredMemoryGB > 0)
            #expect(model.downloadURL.scheme == "https")
        }
    }

    @Test func `hardware profile calculates system fit accurately`() throws {
        // 16 GB RAM Mac
        let profile16GB = AISystemHardwareProfile(totalMemoryBytes: 16 * 1024 * 1024 * 1024)

        let smallModel = try AIModelSpec(
            id: "small",
            name: "Small",
            parameterSize: "1B",
            quantization: "Q4",
            downloadSizeMB: 800,
            requiredMemoryGB: 1.5,
            summary: "test",
            downloadURL: #require(URL(string: "https://example.com")),
            filename: "small.gguf",
        )
        #expect(profile16GB.fit(for: smallModel) == .optimal)

        let heavyModel = try AIModelSpec(
            id: "heavy",
            name: "Heavy",
            parameterSize: "14B",
            quantization: "Q8",
            downloadSizeMB: 12000,
            requiredMemoryGB: 12.0,
            summary: "test",
            downloadURL: #require(URL(string: "https://example.com")),
            filename: "heavy.gguf",
        )
        #expect(profile16GB.fit(for: heavyModel) == .heavy)
    }

    @Test func `alternative and recommendation models store and compare properties`() {
        let alt = AIPackageAlternative(
            name: "ripgrep",
            relationship: "Modern Rust Replacement",
            headline: "Fast search",
            keyAdvantages: ["SIMD acceleration"],
            installCommand: "brew install ripgrep",
        )
        #expect(alt.id == "ripgrep")
        #expect(alt.name == "ripgrep")
        #expect(alt.isFormula)

        let rec = AIPackageRecommendation(
            packageName: "raycast",
            category: "Productivity",
            reason: "Extensible launcher",
            confidenceScore: 0.95,
            isCask: true,
        )
        #expect(rec.id == "raycast")
        #expect(rec.isCask)
        #expect(rec.confidenceScore == 0.95)

        let row = AIComparisonRow(feature: "Speed", packageAValue: "Fast", packageBValue: "Faster")
        #expect(row.id == "Speed")
        #expect(row.packageAValue == "Fast")
    }

    @Test func `housekeeping and safety levels format properly`() {
        #expect(AISafetyLevel.safeToPrune.title == "Safe to Remove")
        #expect(AISafetyLevel.reviewRecommended.title == "Review First")

        let candidate = AIOrphanCandidate(
            packageName: "libpng",
            installedVersion: "1.6.40",
            reason: "Leaf library",
            safetyLevel: .safeToPrune,
        )
        #expect(candidate.id == "libpng")

        let report = AIHousekeepingReport(
            orphanCandidates: [candidate],
            summary: "1 orphan",
            recommendedCommands: ["brew autoremove"],
            reclaimableEstimate: "150 MB",
        )
        #expect(report.orphanCandidates.count == 1)
        #expect(report.reclaimableEstimate == "150 MB")
    }
}
