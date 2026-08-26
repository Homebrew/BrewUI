//
//  SearchFocusArbiterTests.swift
//  BrewTests
//

@testable import BrewUIComponents
import Foundation
import Testing

struct SearchFocusArbiterTests {
    // MARK: - Initial state

    @Test func `nothing holds the keyboard before anything loads`() {
        let arbiter = SearchFocusArbiter()

        #expect(arbiter.target == nil)
        #expect(!arbiter.isSearchFieldPresented)
        #expect(!arbiter.isSearchFocusPending)
    }

    // MARK: - The list claiming focus

    @Test func `the list claims the keyboard once its content loads`() {
        var arbiter = SearchFocusArbiter()

        arbiter.contentDidLoad()

        #expect(arbiter.target == .list)
    }

    @Test func `the list reclaims the keyboard after losing it`() {
        var arbiter = SearchFocusArbiter()

        arbiter.contentDidLoad()
        arbiter.focusDidChange(to: nil)
        arbiter.contentDidLoad()

        #expect(arbiter.target == .list)
    }

    // MARK: - Cmd-F on a field that is already in the toolbar

    @Test func `the search field takes the keyboard when it is already presented`() {
        var arbiter = SearchFocusArbiter(target: .list, isSearchFieldPresented: true)

        arbiter.requestSearchFocus()

        #expect(arbiter.target == .searchField)
        #expect(!arbiter.isSearchFocusPending)
    }

    @Test func `repeat requests keep the keyboard in the search field`() {
        var arbiter = SearchFocusArbiter(target: .list, isSearchFieldPresented: true)

        arbiter.requestSearchFocus()
        arbiter.requestSearchFocus()
        arbiter.requestSearchFocus()

        #expect(arbiter.target == .searchField)
    }

    // MARK: - Cmd-F on a field that must be presented first

    @Test func `requesting focus presents a field that is not in the toolbar yet`() {
        var arbiter = SearchFocusArbiter()

        arbiter.requestSearchFocus()

        #expect(arbiter.isSearchFieldPresented)
        #expect(arbiter.isSearchFocusPending)
    }

    /// The defect: the list used to resign in the same turn, leaving the keyboard nowhere.
    @Test func `the list keeps the keyboard until the search field can accept it`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.requestSearchFocus()

        #expect(arbiter.target == .list)
    }

    @Test func `the pending claim lands once the field is presented`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.requestSearchFocus()
        arbiter.searchFieldDidPresent()

        #expect(arbiter.target == .searchField)
        #expect(!arbiter.isSearchFocusPending)
    }

    @Test func `presenting without a pending claim leaves the keyboard where it is`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.searchFieldDidPresent()

        #expect(arbiter.target == .list)
        #expect(arbiter.isSearchFieldPresented)
    }

    // MARK: - The race that failed on CI

    @Test func `content loading while a search claim is pending does not steal the keyboard`() {
        var arbiter = SearchFocusArbiter()

        arbiter.requestSearchFocus()
        arbiter.contentDidLoad()
        arbiter.searchFieldDidPresent()

        #expect(arbiter.target == .searchField)
    }

    @Test func `content loading while the search field holds the keyboard does not steal it`() {
        var arbiter = SearchFocusArbiter(target: .list, isSearchFieldPresented: true)

        arbiter.requestSearchFocus()
        arbiter.contentDidLoad()

        #expect(arbiter.target == .searchField)
    }

    /// Replays the CI ordering: the Upgrades list loads and takes focus, then ⌘F arrives.
    @Test func `cmd-F wins after the list has already claimed the keyboard`() {
        var arbiter = SearchFocusArbiter()

        arbiter.contentDidLoad()
        arbiter.focusDidChange(to: .list)
        arbiter.requestSearchFocus()
        arbiter.searchFieldDidPresent()

        #expect(arbiter.target == .searchField)
        #expect(!arbiter.isSearchFocusPending)
    }

    // MARK: - Mirroring what SwiftUI actually did

    @Test func `focus reported by SwiftUI becomes the current target`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.focusDidChange(to: .searchField)

        #expect(arbiter.target == .searchField)
    }

    /// SwiftUI resigns the search field on its way out of the toolbar, after `searchFieldDidDismiss`
    /// has already handed the list back the keyboard. Honouring that nil left the keyboard nowhere.
    @Test func `losing focus does not clear the target`() {
        var arbiter = SearchFocusArbiter(target: .searchField, isSearchFieldPresented: true)

        arbiter.searchFieldDidDismiss()
        arbiter.focusDidChange(to: nil)

        #expect(arbiter.target == .list)
    }

    @Test func `losing focus while a claim is pending does not cancel the claim`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.requestSearchFocus()
        arbiter.focusDidChange(to: nil)

        #expect(arbiter.isSearchFocusPending)
        #expect(arbiter.target == .list)
    }

    @Test func `the search field taking focus clears a pending claim`() {
        var arbiter = SearchFocusArbiter()

        arbiter.requestSearchFocus()
        arbiter.focusDidChange(to: .searchField)

        #expect(arbiter.target == .searchField)
        #expect(!arbiter.isSearchFocusPending)
    }

    // MARK: - Dismissal

    @Test func `dismissing the search field hands the keyboard back to the list`() {
        var arbiter = SearchFocusArbiter(target: .searchField, isSearchFieldPresented: true)

        arbiter.searchFieldDidDismiss()

        #expect(arbiter.target == .list)
        #expect(!arbiter.isSearchFieldPresented)
    }

    @Test func `dismissing drops a claim that never landed`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.requestSearchFocus()
        arbiter.searchFieldDidDismiss()

        #expect(!arbiter.isSearchFocusPending)
        #expect(arbiter.target == .list)
    }

    @Test func `an empty search field collapses once the keyboard leaves it`() {
        var arbiter = SearchFocusArbiter(target: .searchField, isSearchFieldPresented: true)

        arbiter.focusDidChange(to: .list)
        arbiter.emptySearchFieldDidLoseFocus()

        #expect(!arbiter.isSearchFieldPresented)
        #expect(arbiter.target == .list)
    }

    @Test func `a pending claim keeps the field it just presented`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.requestSearchFocus()
        arbiter.emptySearchFieldDidLoseFocus()

        #expect(arbiter.isSearchFieldPresented)
        #expect(arbiter.isSearchFocusPending)
    }

    @Test func `dismissing while the list holds the keyboard leaves it there`() {
        var arbiter = SearchFocusArbiter(target: .list, isSearchFieldPresented: true)

        arbiter.searchFieldDidDismiss()

        #expect(arbiter.target == .list)
    }

    // MARK: - Clicking away from the field

    @Test func `a click outside an empty field collapses it and hands the list the keyboard`() {
        var arbiter = SearchFocusArbiter(target: .searchField, isSearchFieldPresented: true)

        arbiter.clickLandedOutsideSearchField(searchFieldIsEmpty: true)

        #expect(!arbiter.isSearchFieldPresented)
        #expect(arbiter.target == .list)
    }

    @Test func `a click outside a field with a query leaves the field in the toolbar`() {
        var arbiter = SearchFocusArbiter(target: .searchField, isSearchFieldPresented: true)

        arbiter.clickLandedOutsideSearchField(searchFieldIsEmpty: false)

        #expect(arbiter.isSearchFieldPresented)
        #expect(arbiter.target == .list)
    }

    @Test func `a click outside does not cancel a pending claim`() {
        var arbiter = SearchFocusArbiter(target: .list)

        arbiter.requestSearchFocus()
        arbiter.clickLandedOutsideSearchField(searchFieldIsEmpty: true)

        #expect(arbiter.isSearchFieldPresented)
        #expect(arbiter.isSearchFocusPending)
    }
}
