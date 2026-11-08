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

    @Test func `hardware profile calculates system fit accurately`() {
        // 16 GB RAM Mac
        let profile16GB = AISystemHardwareProfile(totalMemoryBytes: 16 * 1024 * 1024 * 1024)

        let smallModel = AIModelSpec(
            id: "small",
            name: "Small",
            parameterSize: "1B",
            quantization: "Q4",
            downloadSizeMB: 800,
            requiredMemoryGB: 1.5,
            summary: "test",
            downloadURL: URL(string: "https://example.com")!,
            filename: "small.gguf"
        )
        #expect(profile16GB.fit(for: smallModel) == .optimal)

        let heavyModel = AIModelSpec(
            id: "heavy",
            name: "Heavy",
            parameterSize: "14B",
            quantization: "Q8",
            downloadSizeMB: 12000,
            requiredMemoryGB: 12.0,
            summary: "test",
            downloadURL: URL(string: "https://example.com")!,
            filename: "heavy.gguf"
        )
        #expect(profile16GB.fit(for: heavyModel) == .heavy)
    }
}
