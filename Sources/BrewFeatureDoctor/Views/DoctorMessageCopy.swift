//
//  DoctorMessageCopy.swift
//  BrewFeatureDoctor
//

import Foundation

/// Localises only recognised Homebrew diagnostic prose for the structured Doctor UI.
/// Unknown text stays verbatim, and commands, package names, paths, links and raw output never pass
/// through this boundary. Homebrew has no stable finding identifiers, so matches use known wording
/// or anchored templates that retain their variable path unchanged.
enum DoctorMessageCopy {
    static var warningPreamble: String {
        switch DoctorCopy.warningPreamble {
        case """
        Please note that these warnings are just used to help the Homebrew maintainers \
        with debugging if you file an issue. If everything you use Homebrew for is \
        working fine: please don't worry or file an issue; just ignore this. Thanks!
        """:
            String(localized: """
                   Please note that these warnings are just used to help the Homebrew maintainers \
                   with debugging if you file an issue. If everything you use Homebrew for is \
                   working fine: please don't worry or file an issue; just ignore this. Thanks!
                   """, bundle: #bundle,
                   comment: "Doctor reassurance: findings help Homebrew maintainers but need not be reported if everything works")
        default:
            DoctorCopy.warningPreamble
        }
    }

    static func title(_ source: String, bundle: Bundle = .module) -> String {
        switch source {
        case "Some installed formulae are deprecated or disabled.":
            return resolve(LocalizedStringResource("Some installed formulae are deprecated or disabled.", bundle: #bundle,
                                                   comment: "Doctor finding: installed formulae need replacements"), bundle: bundle)
        case "Some installed casks are deprecated or disabled.":
            return resolve(LocalizedStringResource("Some installed casks are deprecated or disabled.", bundle: #bundle,
                                                   comment: "Doctor finding: installed casks need replacements"), bundle: bundle)
        case "The following taps are not trusted:":
            return resolve(LocalizedStringResource("The following taps are not trusted:", bundle: #bundle,
                                                   comment: "Doctor finding: untrusted Homebrew taps are listed below"), bundle: bundle)
        case "You have unlinked kegs in your Cellar.":
            return resolve(LocalizedStringResource("You have unlinked kegs in your Cellar.", bundle: #bundle,
                                                   comment: "Doctor finding: installed kegs are not linked into the Homebrew prefix"), bundle: bundle)
        default:
            if let path = value(in: source, prefix: "Unbrewed dylibs were found in ", suffix: ".") {
                return resolve(LocalizedStringResource("Unbrewed dylibs were found in \(path).", bundle: #bundle,
                                                       comment: "Doctor finding: %@ is a filesystem path containing unmanaged dynamic libraries"), bundle: bundle)
            }
            if let path = value(in: source, prefix: "Unbrewed static libraries were found in ", suffix: ".") {
                return resolve(LocalizedStringResource("Unbrewed static libraries were found in \(path).", bundle: #bundle,
                                                       comment: "Doctor finding: %@ is a filesystem path containing unmanaged static libraries"), bundle: bundle)
            }
            if let path = value(in: source, prefix: "Unbrewed '.pc' files were found in ", suffix: ".") {
                return resolve(LocalizedStringResource("Unbrewed '.pc' files were found in \(path).", bundle: #bundle,
                                                       comment: "Doctor finding: %@ is a filesystem path containing unmanaged pkg-config files"), bundle: bundle)
            }
            if let path = value(in: source, prefix: "Unbrewed header files were found in ", suffix: ".") {
                return resolve(LocalizedStringResource("Unbrewed header files were found in \(path).", bundle: #bundle,
                                                       comment: "Doctor finding: %@ is a filesystem path containing unmanaged headers"), bundle: bundle)
            }
            if let path = value(in: source, prefix: "Unbrewed '.la' files were found in ", suffix: ".") {
                return resolve(LocalizedStringResource("Unbrewed '.la' files were found in \(path).", bundle: #bundle,
                                                       comment: "Doctor finding: %@ is a filesystem path containing unmanaged .la files"), bundle: bundle)
            }
            return source
        }
    }

    static func prose(_ lines: [String]) -> String {
        var rendered: [String] = []
        var index = 0
        while index < lines.count {
            if index + 1 < lines.count, let translation = pairedProse(lines[index], lines[index + 1]) {
                rendered.append(translation)
                index += 2
            } else {
                rendered.append(singleLineProse(lines[index]))
                index += 1
            }
        }
        return rendered.joined(separator: "\n")
    }

    private static func pairedProse(_ first: String, _ second: String) -> String? {
        switch (first, second) {
        case ("If you didn't put them there on purpose they could cause problems when",
              "building Homebrew formulae and may need to be deleted."):
            String(localized: """
                   If you didn't put them there on purpose they could cause problems when \
                   building Homebrew formulae and may need to be deleted.
                   """, bundle: #bundle,
                   comment: "Doctor explanation: unexpected files may interfere with formula builds")
        case ("Homebrew is currently ignoring formulae, casks and commands",
              "from these taps because tap trust is required."):
            String(localized: "Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.", bundle: #bundle,
                   comment: "Doctor explanation: untrusted taps are not used")
        case ("Whole-tap trust is broader and includes all current and future formulae,",
              "casks and commands from the listed taps. Trust whole taps with:"):
            String(localized: """
                   Whole-tap trust is broader and includes all current and future formulae, \
                   casks and commands from the listed taps. Trust whole taps with:
                   """, bundle: #bundle,
                   comment: "Doctor warning: whole-tap trust covers future content too")
        case ("Leaving kegs unlinked can lead to build-trouble and cause formulae that depend on",
              "those kegs to fail to run properly once built."):
            String(localized: "Leaving kegs unlinked can lead to build-trouble and cause formulae that depend on those kegs to fail to run properly once built.", bundle: #bundle,
                   comment: "Doctor explanation: unlinked kegs can break builds and dependent formulae")
        default:
            nil
        }
    }

    private static func singleLineProse(_ source: String) -> String {
        switch source {
        case "Prefer trusting only the specific formulae, casks or commands you need.":
            String(localized: "Prefer trusting only the specific formulae, casks or commands you need.", bundle: #bundle,
                   comment: "Doctor advice: prefer narrow trust grants")
        default:
            caption(source)
        }
    }

    static func caption(_ source: String, bundle: Bundle = .module) -> String {
        switch source {
        case "You should find replacements for the following formulae:":
            resolve(LocalizedStringResource("You should find replacements for the following formulae:", bundle: #bundle,
                                            comment: "Doctor heading: deprecated formulae list follows"), bundle: bundle)
        case "You should find replacements for the following casks:":
            resolve(LocalizedStringResource("You should find replacements for the following casks:", bundle: #bundle,
                                            comment: "Doctor heading: deprecated casks list follows"), bundle: bundle)
        case "Unexpected header files:":
            resolve(LocalizedStringResource("Unexpected header files:", bundle: #bundle,
                                            comment: "Doctor heading: unmanaged header paths follow"), bundle: bundle)
        case "Unexpected dylibs:":
            resolve(LocalizedStringResource("Unexpected dylibs:", bundle: #bundle,
                                            comment: "Doctor heading: unmanaged dynamic library paths follow"), bundle: bundle)
        case "Unexpected static libraries:":
            resolve(LocalizedStringResource("Unexpected static libraries:", bundle: #bundle,
                                            comment: "Doctor heading: unmanaged static library paths follow"), bundle: bundle)
        case "Unexpected '.pc' files:":
            resolve(LocalizedStringResource("Unexpected '.pc' files:", bundle: #bundle,
                                            comment: "Doctor heading: unmanaged pkg-config file paths follow"), bundle: bundle)
        case "Unexpected '.la' files:":
            resolve(LocalizedStringResource("Unexpected '.la' files:", bundle: #bundle,
                                            comment: "Doctor heading: unmanaged .la file paths follow"), bundle: bundle)
        default:
            otherCaption(source, bundle: bundle)
        }
    }

    private static func otherCaption(_ source: String, bundle: Bundle) -> String {
        switch source {
        case "Trust installed formulae from these taps with:":
            resolve(LocalizedStringResource("Trust installed formulae from these taps with:", bundle: #bundle,
                                            comment: "Doctor heading: narrow trust command for installed formulae follows"), bundle: bundle)
        case "Trust installed casks from these taps with:":
            resolve(LocalizedStringResource("Trust installed casks from these taps with:", bundle: #bundle,
                                            comment: "Doctor heading: narrow trust command for installed casks follows"), bundle: bundle)
        case "Trust other specific casks and commands with:":
            resolve(LocalizedStringResource("Trust other specific casks and commands with:", bundle: #bundle,
                                            comment: "Doctor heading: narrow trust commands for casks and commands follow"), bundle: bundle)
        case "Untap them with:":
            resolve(LocalizedStringResource("Untap them with:", bundle: #bundle,
                                            comment: "Doctor heading: commands to remove untrusted taps follow"), bundle: bundle)
        case "For more information, see:":
            resolve(LocalizedStringResource("For more information, see:", bundle: #bundle,
                                            comment: "Doctor heading: reference URL follows"), bundle: bundle)
        case "Affects:":
            resolve(LocalizedStringResource("Affects:", bundle: #bundle,
                                            comment: "Doctor heading: affected packages follow"), bundle: bundle)
        case "More information:":
            resolve(LocalizedStringResource("More information:", bundle: #bundle,
                                            comment: "Doctor heading: reference links follow"), bundle: bundle)
        case "Run `brew link` on these:":
            resolve(LocalizedStringResource("Run `brew link` on these:", bundle: #bundle,
                                            comment: "Doctor heading: packages to link with the literal brew link command follow"), bundle: bundle)
        case "You can solve this by running:":
            resolve(LocalizedStringResource("You can solve this by running:", bundle: #bundle,
                                            comment: "Doctor heading: suggested Homebrew commands follow"), bundle: bundle)
        default:
            title(source, bundle: bundle)
        }
    }

    /// Catalogue keys are the English defaults. Keep extraction metadata at the call site while
    /// resolving the interpolated value in the selected bundle, without changing global language.
    private static func resolve(_ resource: LocalizedStringResource, bundle: Bundle) -> String {
        String(localized: resource.defaultValue, table: resource.table, bundle: bundle)
    }

    private static func value(in source: String, prefix: String, suffix: String) -> String? {
        guard source.hasPrefix(prefix), source.hasSuffix(suffix) else {
            return nil
        }
        let value = source.dropFirst(prefix.count).dropLast(suffix.count)
        return value.isEmpty || value.contains("\n") ? nil : String(value)
    }
}
