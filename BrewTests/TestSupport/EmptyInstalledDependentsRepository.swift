@testable import Brew
import Foundation

struct EmptyInstalledDependentsRepository: InstalledDependentsRepository {
    func installedDependents(for _: BrewPackage.ID) async -> [BrewPackage] {
        []
    }
}
