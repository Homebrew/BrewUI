@testable import Brew
import Foundation

struct EmptyInstalledDependentsRepository: InstalledDependentsRepository {
    func installedDependents(for _: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        []
    }
}
