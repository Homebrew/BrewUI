//
//  LocalizationBundleTests.swift
//  BrewUIComponentsTests
//

@testable import BrewUIComponents
import Foundation
import Testing

/// Pins the wiring, not the wording. A `LocalizedStringResource` built without an explicit bundle
/// resolves against `Bundle.main` — the app, not the module — and the failure is silent: the lookup
/// returns the key, so the string just stays English. These tests name that failure mode directly.
///
/// Resolved translations are asserted in `BrewTests/LocalizationResolutionTests.swift` instead:
/// `swift test` never compiles the catalogue, so resolution cannot be observed from here.
struct LocalizationBundleTests {
    @Test func `a module string keeps its key`() {
        #expect(LocalizedStringResource(uiComponents: "Retry").key == "Retry")
    }

    @Test func `a module string points at the module bundle, not main`() {
        // `BundleDescription` is not Equatable, so the case is matched rather than compared.
        guard case let .atURL(url) = LocalizedStringResource(uiComponents: "Retry").bundle else {
            Issue.record("Expected .atURL — a .main bundle means the module catalogue is unreachable")
            return
        }
        #expect(url.lastPathComponent == "BrewKit_BrewUIComponents.bundle")
    }
}
