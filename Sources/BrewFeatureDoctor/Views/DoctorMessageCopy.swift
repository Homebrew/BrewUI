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

    static func title(_ source: String) -> String {
        switch source {
        case "Some installed formulae are deprecated or disabled.":
            return String(localized: "Some installed formulae are deprecated or disabled.", bundle: #bundle,
                          comment: "Doctor finding: installed formulae need replacements")
        case "Some installed casks are deprecated or disabled.":
            return String(localized: "Some installed casks are deprecated or disabled.", bundle: #bundle,
                          comment: "Doctor finding: installed casks need replacements")
        case "The following taps are not trusted:":
            return String(localized: "The following taps are not trusted:", bundle: #bundle,
                          comment: "Doctor finding: untrusted Homebrew taps are listed below")
        default:
            if let path = value(in: source, prefix: "Unbrewed header files were found in ", suffix: ".") {
                return String(localized: "Unbrewed header files were found in \(path).", bundle: #bundle,
                              comment: "Doctor finding: %@ is a filesystem path containing unmanaged headers")
            }
            if let path = value(in: source, prefix: "Unbrewed '.la' files were found in ", suffix: ".") {
                return String(localized: "Unbrewed '.la' files were found in \(path).", bundle: #bundle,
                              comment: "Doctor finding: %@ is a filesystem path containing unmanaged .la files")
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

    static func caption(_ source: String) -> String {
        switch source {
        case "You should find replacements for the following formulae:":
            String(localized: "You should find replacements for the following formulae:", bundle: #bundle,
                   comment: "Doctor heading: deprecated formulae list follows")
        case "You should find replacements for the following casks:":
            String(localized: "You should find replacements for the following casks:", bundle: #bundle,
                   comment: "Doctor heading: deprecated casks list follows")
        case "Unexpected header files:":
            String(localized: "Unexpected header files:", bundle: #bundle,
                   comment: "Doctor heading: unmanaged header paths follow")
        case "Unexpected '.la' files:":
            String(localized: "Unexpected '.la' files:", bundle: #bundle,
                   comment: "Doctor heading: unmanaged .la file paths follow")
        default:
            otherCaption(source)
        }
    }

    private static func otherCaption(_ source: String) -> String {
        switch source {
        case "Trust installed formulae from these taps with:":
            String(localized: "Trust installed formulae from these taps with:", bundle: #bundle,
                   comment: "Doctor heading: narrow trust command for installed formulae follows")
        case "Trust installed casks from these taps with:":
            String(localized: "Trust installed casks from these taps with:", bundle: #bundle,
                   comment: "Doctor heading: narrow trust command for installed casks follows")
        case "Trust other specific casks and commands with:":
            String(localized: "Trust other specific casks and commands with:", bundle: #bundle,
                   comment: "Doctor heading: narrow trust commands for casks and commands follow")
        case "Untap them with:":
            String(localized: "Untap them with:", bundle: #bundle,
                   comment: "Doctor heading: commands to remove untrusted taps follow")
        case "For more information, see:":
            String(localized: "For more information, see:", bundle: #bundle,
                   comment: "Doctor heading: reference URL follows")
        case "Affects:":
            String(localized: "Affects:", bundle: #bundle,
                   comment: "Doctor heading: affected packages follow")
        case "More information:":
            String(localized: "More information:", bundle: #bundle,
                   comment: "Doctor heading: reference links follow")
        default:
            title(source)
        }
    }

    private static func value(in source: String, prefix: String, suffix: String) -> String? {
        guard source.hasPrefix(prefix), source.hasSuffix(suffix) else {
            return nil
        }
        let value = source.dropFirst(prefix.count).dropLast(suffix.count)
        return value.isEmpty || value.contains("\n") ? nil : String(value)
    }
}
