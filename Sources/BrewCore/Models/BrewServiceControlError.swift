/// Service controls cannot proceed, or their refreshed state does not confirm success.
public enum BrewServiceControlError: Error, Equatable, Sendable {
    case unavailable
    case stateNotReached
}
