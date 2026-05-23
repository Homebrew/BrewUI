@testable import BrewUILint
import Testing

@Suite("PackageIDRule")
struct PackageIDRuleTests {
    @Test
    func `package type with canonical ID passes`() {
        let source = """
        struct BrewPackage {
            var id: HomebrewPackageID
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.isEmpty)
    }

    @Test
    func `package type with string ID fails`() {
        let source = """
        struct HomebrewPackage {
            let id: String
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.count == 1)
        #expect(violations[0].ruleID == PackageIDRule.identifier)
    }

    @Test
    func `extension with wrong ID fails`() {
        let source = """
        extension InstalledBrewPackage {
            var id: String { "x" }
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.count == 1)
    }

    @Test
    func `nested package type fails`() {
        let source = """
        struct Container {
            struct InnerPackage {
                let id: Int
            }
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.count == 1)
    }

    @Test
    func `package list type ignored`() {
        let source = """
        struct PackageList {
            let id: String
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.isEmpty)
    }

    @Test
    func `non package type ignored`() {
        let source = """
        struct RowModel {
            let id: String
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.isEmpty)
    }

    @Test
    func `package type non ID binding ignored`() {
        let source = """
        struct BrewPackage {
            let packageID: String
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.isEmpty)
    }

    @Test
    func `canonical identity enum ignored`() {
        let source = """
        enum HomebrewPackageID {
            var id: Self { self }
        }
        """
        let violations = LintHarness.lintPackageIDRule(source)
        #expect(violations.isEmpty)
    }
}
