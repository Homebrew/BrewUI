import BrewCore
import Foundation

public enum AppMessage {
    case raw(String)
    case localized(String.LocalizationValue)

    public init(failure: OperationFailure) {
        switch failure {
        case let .brewCommand(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            self = trimmed.isEmpty ? .localized("Homebrew command failed.") : .raw(trimmed)
        case let .brewLaunchFailed(diagnostic):
            self = .raw(diagnostic)
        case .brewExecutableNotFound:
            self = .localized("Could not find Homebrew. Install it or ensure brew is in the default location.")
        case let .generic(userFacing, _):
            self = .raw(userFacing)
        }
    }

    public func string(localization: AppLocalization) -> String {
        switch self {
        case let .raw(value): value
        case let .localized(value): localization.string(value)
        }
    }
}
