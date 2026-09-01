//
//  BrewActionButtonAppearanceTests.swift
//  BrewUIComponentsTests
//

@testable import BrewUIComponents
import Foundation
import Testing

struct BrewActionButtonAppearanceTests {
    @Test func `a button at rest shows its own title and icon`() {
        let appearance = BrewActionButtonAppearance(
            title: "Copy",
            systemImage: "doc.on.doc",
            confirmationTitle: "Copied",
            isConfirming: false,
        )

        #expect(appearance == BrewActionButtonAppearance(
            title: "Copy",
            systemImage: "doc.on.doc",
            confirmationTitle: nil,
            isConfirming: false,
        ))
    }

    @Test func `a confirming button shows a tick and its confirmation title`() {
        let appearance = BrewActionButtonAppearance(
            title: "Clear",
            systemImage: "trash",
            confirmationTitle: "Cleared",
            isConfirming: true,
        )

        #expect((appearance.title, appearance.systemImage) == ("Cleared", "checkmark"))
    }

    @Test func `a button without a confirmation title never changes`() {
        let appearance = BrewActionButtonAppearance(
            title: "Save",
            systemImage: "square.and.arrow.down",
            confirmationTitle: nil,
            isConfirming: true,
        )

        #expect((appearance.title, appearance.systemImage) == ("Save", "square.and.arrow.down"))
    }
}
