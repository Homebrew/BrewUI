@testable import BrewLocalizeCore
import Foundation

enum Fixtures {
    static func catalog(_ json: String) throws -> StringCatalog {
        try StringCatalog(data: Data(json.utf8))
    }

    static let package = CatalogLocation(path: "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings")
    static let app = CatalogLocation(path: CatalogLocation.appCatalogPath)

    /// One key in every state the status report distinguishes, for `en-GB`.
    static let mixed = """
    {
      "sourceLanguage" : "en",
      "version" : "1.0",
      "strings" : {
        "Translated" : {
          "comment" : "c",
          "localizations" : { "en-GB" : { "stringUnit" : { "state" : "translated", "value" : "T" } } }
        },
        "Review" : {
          "comment" : "c",
          "localizations" : { "en-GB" : { "stringUnit" : { "state" : "needs_review", "value" : "R" } } }
        },
        "New" : {
          "comment" : "c",
          "localizations" : { "en-GB" : { "stringUnit" : { "state" : "new", "value" : "" } } }
        },
        "Missing" : { "comment" : "c" },
        "Stale" : {
          "comment" : "c",
          "extractionState" : "stale",
          "localizations" : { "en-GB" : { "stringUnit" : { "state" : "translated", "value" : "S" } } }
        },
        "Do not translate" : { "comment" : "c", "shouldTranslate" : false },
        "%lld packages" : {
          "comment" : "c",
          "localizations" : {
            "en-GB" : {
              "variations" : {
                "plural" : {
                  "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld package" } },
                  "other" : { "stringUnit" : { "state" : "new", "value" : "" } }
                }
              }
            }
          }
        }
      }
    }
    """
}
