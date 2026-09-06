//
//  NoteCalloutToneTests.swift
//  BrewUIComponentsTests
//

@testable import BrewUIComponents
import SwiftUI
import Testing

struct NoteCalloutToneTests {
    @Test func `the brand tone draws Homebrew amber`() {
        #expect(NoteCalloutTone.brand.iconColor == Color.brewTextBrand)
        #expect(NoteCalloutTone.brand.background == Color.brewBrandTint)
    }

    @Test func `the info tone draws the information blue`() {
        #expect(NoteCalloutTone.info.iconColor == Color.brewStatusInfo)
        #expect(NoteCalloutTone.info.background == Color.brewStatusInfoSubtle)
    }

    /// The two tones exist to be told apart on screen; sharing a token would defeat the point.
    @Test func `the tones never share a token`() {
        #expect(NoteCalloutTone.brand.iconColor != NoteCalloutTone.info.iconColor)
        #expect(NoteCalloutTone.brand.background != NoteCalloutTone.info.background)
    }
}
