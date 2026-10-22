public import Foundation

/// The desired librime options for one text field: Chinese/English state, punctuation
/// and 简繁. The controller supplies what the session currently holds; this module owns
/// the rules for what it should hold, including Caps Lock undo and remembered state.
public struct InputOptions: Sendable {
    public struct Session: Sendable, Equatable {
        public var asciiMode: Bool
        public var asciiPunct: Bool
        public var simplification: Bool

        public init(asciiMode: Bool, asciiPunct: Bool, simplification: Bool) {
            self.asciiMode = asciiMode
            self.asciiPunct = asciiPunct
            self.simplification = simplification
        }
    }

    public struct Context: Sendable {
        public var app: String?
        /// `app_options/<app>/ascii_mode` (true = English), nil when not configured.
        public var appDefault: Bool?
        /// `app_options/<app>/ascii_punct`, nil when the app follows the shared state.
        public var appPunctuation: Bool?
        public var newSession: Bool
        public var isActive: Bool
        public var features: HufuFeatures
        public var current: Session
        /// `switcher/save_options` lists `ascii_punct`: the first session inherits the
        /// state librime remembered instead of the Settings switch.
        public var remembersPunctuation: Bool

        public init(
            app: String? = nil,
            appDefault: Bool? = nil,
            appPunctuation: Bool? = nil,
            newSession: Bool = false,
            isActive: Bool = true,
            features: HufuFeatures = HufuFeatures(),
            current: Session,
            remembersPunctuation: Bool = false
        ) {
            self.app = app
            self.appDefault = appDefault
            self.appPunctuation = appPunctuation
            self.newSession = newSession
            self.isActive = isActive
            self.features = features
            self.current = current
            self.remembersPunctuation = remembersPunctuation
        }
    }

    public struct Desired: Sendable, Equatable {
        public var asciiMode: Bool?
        public var asciiPunct: Bool?
        public var simplification: Bool?

        public init(asciiMode: Bool? = nil, asciiPunct: Bool? = nil, simplification: Bool? = nil) {
            self.asciiMode = asciiMode
            self.asciiPunct = asciiPunct
            self.simplification = simplification
        }

        public var isEmpty: Bool { asciiMode == nil && asciiPunct == nil && simplification == nil }
    }

    public private(set) var asciiState = AsciiStatePolicy()
    /// nil until the first session seeds it from librime or the feature switch.
    public private(set) var sharedPunctuation: Bool?
    private var capsSwitch = CapsLockSourceSwitch()

    public init() {}

    public var asciiScope: AsciiStateScope { asciiState.scope }

    public mutating func setAsciiScope(_ scope: AsciiStateScope) { asciiState.scope = scope }

    /// A new text field: a Caps Lock press from the previous one must not undo anything.
    public mutating func beginActivation() {
        capsSwitch = CapsLockSourceSwitch()
    }

    /// What the session should hold now. A nil field means "leave it alone".
    public mutating func desired(for context: Context) -> Desired {
        var desired = Desired()

        if let mode = asciiState.state(for: context.app, appDefault: context.appDefault, newSession: context.newSession),
           mode != context.current.asciiMode {
            desired.asciiMode = mode
        }

        if sharedPunctuation == nil {
            sharedPunctuation = context.remembersPunctuation
                ? context.current.asciiPunct
                : context.features.asciiPunct
        }
        let punctuation = context.appPunctuation ?? sharedPunctuation ?? false
        if punctuation != context.current.asciiPunct { desired.asciiPunct = punctuation }

        let traditional = context.features.scriptMode.usesTraditionalConversion
        if traditional != context.current.simplification { desired.simplification = traditional }

        return desired
    }

    /// Publishes the state the user leaves behind, for the next text field: ascii state
    /// through its scope policy and the shared punctuation unless the app pins its own.
    public mutating func remember(_ context: Context) {
        guard context.isActive else { return }
        if context.appPunctuation == nil { sharedPunctuation = context.current.asciiPunct }
        asciiState.record(
            context.current.asciiMode,
            app: context.app,
            appDefault: context.appDefault,
            isActive: context.isActive
        )
    }

    /// The Settings switch changed while a session was alive. It becomes the shared
    /// state only after the first session seeded the sentinel.
    public mutating func punctuationFeatureChanged(_ enabled: Bool) {
        guard sharedPunctuation != nil else { return }
        sharedPunctuation = enabled
    }

    public mutating func capsLockPressed(asciiBefore: Bool, at now: Date = Date()) {
        capsSwitch.pressed(asciiBefore: asciiBefore, at: now)
    }

    /// The Chinese/English state to restore when macOS used Caps Lock to switch input
    /// sources, or nil when this deactivation is not that case.
    public mutating func undoCapsLockSwitch(currentAscii: Bool, at now: Date = Date()) -> Bool? {
        guard let restore = capsSwitch.deactivated(at: now), restore != currentAscii else { return nil }
        return restore
    }
}
