@testable import Brew
import Foundation

struct EmptyInstalledInventoryReading: InstalledInventoryReading {
    func installedPackageIDs() async -> Set<BrewPackage.ID> {
        []
    }
}
