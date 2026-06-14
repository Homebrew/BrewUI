//
//  InstalledPackageDetailRelationshipListNavigationTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureInstalled
import Testing

@Suite("Relationship list keyboard navigation")
struct RelationshipListNavigationTests {
    @Test @MainActor func `navigable ids include the show more row when collapsed with overflow`() {
        let items = makeRelationshipItems(count: 5)
        let ids = relationshipNavigableIDs(
            relationships: items,
            isExpanded: false,
            collapsedRelationshipCount: 3,
        )

        #expect(ids.count == 4)
        #expect(ids.dropLast() == items.prefix(3).map { .relationship($0.id) })
        #expect(ids.last == .showMore)
    }

    @Test @MainActor func `navigable ids include all rows plus show less when expanded`() {
        let items = makeRelationshipItems(count: 5)
        let ids = relationshipNavigableIDs(
            relationships: items,
            isExpanded: true,
            collapsedRelationshipCount: 3,
        )

        // When expanded, every relationship is navigable AND the Show less row stays so the user
        // can collapse it again with the keyboard.
        #expect(ids.count == 6)
        #expect(ids.dropLast() == items.map { .relationship($0.id) })
        #expect(ids.last == .showMore)
    }

    @Test @MainActor func `navigable ids omit show more when there is no overflow`() {
        let items = makeRelationshipItems(count: 2)
        let ids = relationshipNavigableIDs(
            relationships: items,
            isExpanded: false,
            collapsedRelationshipCount: 3,
        )

        #expect(ids == items.map { .relationship($0.id) })
    }

    @Test @MainActor func `navigable ids are empty when there are no relationships`() {
        let ids = relationshipNavigableIDs(
            relationships: [],
            isExpanded: false,
            collapsedRelationshipCount: 3,
        )
        #expect(ids.isEmpty)
    }

    @Test @MainActor func `auto-expand target is the first newly visible row when collapsed`() {
        let items = makeRelationshipItems(count: 5)
        let target = relationshipAutoExpandTargetID(
            relationships: items,
            isExpanded: false,
            collapsedRelationshipCount: 3,
        )

        #expect(target == .relationship(items[3].id))
    }

    @Test @MainActor func `auto-expand target is nil when the section is already expanded`() {
        let items = makeRelationshipItems(count: 5)
        let target = relationshipAutoExpandTargetID(
            relationships: items,
            isExpanded: true,
            collapsedRelationshipCount: 3,
        )

        #expect(target == nil)
    }

    @Test @MainActor func `auto-expand target is nil when there is no overflow`() {
        let items = makeRelationshipItems(count: 3)
        let target = relationshipAutoExpandTargetID(
            relationships: items,
            isExpanded: false,
            collapsedRelationshipCount: 3,
        )

        #expect(target == nil)
    }

    private func makeRelationshipItems(count: Int) -> [PackageRelationshipItem] {
        (0 ..< count).map { index in
            PackageRelationshipItem(
                displayName: "pkg-\(index)",
                packageKind: .formula,
                targetPackageID: .formula(name: "pkg-\(index)"),
                installedPackageID: .formula(name: "pkg-\(index)"),
            )
        }
    }
}
