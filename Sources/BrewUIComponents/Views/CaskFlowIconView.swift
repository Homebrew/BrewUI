import BrewCore
import Foundation
import SwiftUI

/// Provides the public CaskFlow icon endpoints for a package identity.
public enum CaskFlowIconSource {
    private static let cdnBaseURL = URL(string: "https://cdn.jsdelivr.net/gh/alielsokary/CaskFlow@icons")!
    private static let rawBaseURL = URL(string: "https://raw.githubusercontent.com/alielsokary/CaskFlow/icons")!

    public static func urls(for packageID: HomebrewPackageID) -> [URL] {
        guard case let .cask(token) = packageID else {
            return []
        }
        return [cdnBaseURL, rawBaseURL].map { $0.appendingPathComponent("\(token).png") }
    }
}

/// Loads a CaskFlow icon with a GitHub Raw fallback and keeps the existing symbol when unavailable.
public struct CaskFlowIconView: View {
    private let packageID: HomebrewPackageID
    private let fallbackSystemName: String
    @State private var urlIndex = 0

    public init(packageID: HomebrewPackageID, fallbackSystemName: String) {
        self.packageID = packageID
        self.fallbackSystemName = fallbackSystemName
    }

    public var body: some View {
        let urls = CaskFlowIconSource.urls(for: packageID)
        Group {
            if urlIndex < urls.count {
                AsyncImage(url: urls[urlIndex]) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        if urlIndex + 1 < urls.count {
                            Color.clear
                                .task {
                                    urlIndex += 1
                                }
                        } else {
                            fallbackIcon
                        }
                    case .empty:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
                .id(urlIndex)
            } else {
                fallbackIcon
            }
        }
        .onChange(of: packageID) { _, _ in
            urlIndex = 0
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: fallbackSystemName)
    }
}
