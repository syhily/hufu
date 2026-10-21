public import Foundation

/// Tells a Caps Lock press that macOS used to switch input sources ("Use the Caps Lock
/// key to switch to and from ABC") from one meant for librime. Pure state: the input
/// method reports Caps Lock presses and deactivation with their times.
///
/// macOS still delivers that press to the input method, and librime's ascii_composer
/// reads it as "switch to English". Left alone, the English state is remembered on the
/// way out and comes back with the next switch to Hufu, so a press followed by
/// deactivation within `pressToDeactivate` is undone.
public struct CapsLockSourceSwitch: Sendable, Equatable {
    /// How soon deactivation must follow a press for the two to belong together. The
    /// system switch deactivates within milliseconds; a person pressing Caps Lock and
    /// then leaving the field takes far longer.
    public static let pressToDeactivate: TimeInterval = 0.3

    private var pressedAt: Date?
    private var asciiBeforePress = false

    public init() {}

    /// Records a Caps Lock press that librime handled, with the Chinese/English state
    /// before it (true = English).
    public mutating func pressed(asciiBefore: Bool, at now: Date) {
        pressedAt = now
        asciiBeforePress = asciiBefore
    }

    /// The Chinese/English state to restore when the input method is deactivated right
    /// after a Caps Lock press, or nil to keep the current state.
    public mutating func deactivated(at now: Date) -> Bool? {
        defer { pressedAt = nil }
        guard let pressedAt, now.timeIntervalSince(pressedAt) < Self.pressToDeactivate else { return nil }
        return asciiBeforePress
    }
}
