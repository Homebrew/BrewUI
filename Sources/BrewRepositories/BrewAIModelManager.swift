//
//  BrewAIModelManager.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
public final class BrewAIModelManager: AIModelManaging {
    public let availableModels: [AIModelSpec] = AIModelCatalog.allModels
    public let hardwareProfile = AISystemHardwareProfile()

    private let modelsDirectory: URL
    private let defaults: UserDefaults
    private let activeModelKey = "sh.brew.app.activeAIModel"

    public private(set) var activeModelID: String?
    public private(set) var downloadProgresses: [String: Double] = [:]
    public private(set) var lastErrorMessage: String?
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    public init(modelsDirectory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let directory = modelsDirectory ?? (
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        ).appendingPathComponent("sh.brew.app/Models", isDirectory: true)
        self.modelsDirectory = directory

        try? FileManager.default.createDirectory(at: self.modelsDirectory, withIntermediateDirectories: true)
        if let stored = defaults.string(forKey: activeModelKey), !stored.isEmpty {
            if let model = AIModelCatalog.allModels.first(where: { $0.id == stored }) {
                let fileURL = directory.appendingPathComponent(model.filename)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    activeModelID = stored
                } else {
                    activeModelID = nil
                }
            } else {
                activeModelID = nil
            }
        } else {
            activeModelID = nil
        }
    }

    public func downloadState(for model: AIModelSpec) -> AIModelDownloadState {
        if let progress = downloadProgresses[model.id] {
            return .downloading(progress: progress)
        }
        let fileURL = modelsDirectory.appendingPathComponent(model.filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return .ready
        }
        return .notDownloaded
    }

    public func setActiveModel(id: String?) {
        activeModelID = id
        if let id {
            defaults.set(id, forKey: activeModelKey)
        } else {
            defaults.set("", forKey: activeModelKey)
        }
    }

    public func startDownload(for model: AIModelSpec) async {
        guard downloadTasks[model.id] == nil else { return }
        downloadProgresses[model.id] = 0.05
        lastErrorMessage = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let destinationURL = modelsDirectory.appendingPathComponent(model.filename)

            // Simulate / run download stream with progress updates
            for step in 1 ... 10 {
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
                if !Task.isCancelled {
                    downloadProgresses[model.id] = Double(step) / 10.0
                }
            }

            if !Task.isCancelled {
                // Write a lightweight model descriptor file to represent local availability
                let marker = "Model: \(model.name)\nFormat: \(model.quantization)\n"
                do {
                    try marker.write(to: destinationURL, atomically: true, encoding: .utf8)
                    lastErrorMessage = nil
                } catch {
                    lastErrorMessage = error.localizedDescription
                }
            }

            downloadProgresses.removeValue(forKey: model.id)
            downloadTasks.removeValue(forKey: model.id)
        }

        downloadTasks[model.id] = task
    }

    public func cancelDownload(for model: AIModelSpec) {
        downloadTasks[model.id]?.cancel()
        downloadTasks.removeValue(forKey: model.id)
        downloadProgresses.removeValue(forKey: model.id)
    }

    public func deleteModel(for model: AIModelSpec) {
        cancelDownload(for: model)
        let fileURL = modelsDirectory.appendingPathComponent(model.filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                lastErrorMessage = nil
            } catch {
                lastErrorMessage = error.localizedDescription
                return
            }
        }
        if activeModelID == model.id {
            activeModelID = nil
            defaults.set("", forKey: activeModelKey)
        }
    }
}
