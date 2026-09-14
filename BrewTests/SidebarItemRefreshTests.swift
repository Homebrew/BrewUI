//
//  SidebarItemRefreshTests.swift
//  BrewTests
//

@testable import Homebrew
import Testing

@MainActor
struct SidebarItemRefreshTests {
    @Test func `⌘R re-runs brew doctor from the Doctor screen`() {
        #expect(SidebarItem.doctor.refreshesDoctorReport)
    }

    @Test(arguments: SidebarItem.allCases.filter { $0 != .doctor })
    func `⌘R leaves the doctor report alone from every other screen`(item: SidebarItem) {
        #expect(!item.refreshesDoctorReport)
    }

    @Test func `exactly one sidebar screen re-runs brew doctor`() {
        #expect(SidebarItem.allCases.filter(\.refreshesDoctorReport) == [.doctor])
    }
}
