import Foundation
import Testing
@testable import HufuCore

struct InputOptionsTests {
    private func context(
        current: InputOptions.Session,
        features: HufuFeatures = HufuFeatures(),
        app: String? = nil,
        appDefault: Bool? = nil,
        appPunctuation: Bool? = nil,
        newSession: Bool = false,
        isActive: Bool = true,
        remembersPunctuation: Bool = false
    ) -> InputOptions.Context {
        InputOptions.Context(
            app: app, appDefault: appDefault, appPunctuation: appPunctuation,
            newSession: newSession, isActive: isActive, features: features,
            current: current, remembersPunctuation: remembersPunctuation
        )
    }

    @Test func punctuationSeedsFromTheFeatureOrLibrime() {
        var fromFeature = InputOptions()
        var features = HufuFeatures()
        features.asciiPunct = true
        let desired = fromFeature.desired(for: context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: false),
            features: features))
        #expect(desired.asciiPunct == true)
        #expect(fromFeature.sharedPunctuation == true)

        var fromLibrime = InputOptions()
        features.asciiPunct = false
        let inherited = fromLibrime.desired(for: context(
            current: .init(asciiMode: false, asciiPunct: true, simplification: false),
            features: features, remembersPunctuation: true))
        #expect(inherited.asciiPunct == nil)
        #expect(fromLibrime.sharedPunctuation == true)
    }

    @Test func appPunctuationPinsAndDoesNotOverwriteTheSharedState() {
        var options = InputOptions()
        _ = options.desired(for: context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: false)))
        #expect(options.sharedPunctuation == false)

        let pinned = context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: false),
            appPunctuation: true)
        #expect(options.desired(for: pinned).asciiPunct == true)
        options.remember(context(
            current: .init(asciiMode: false, asciiPunct: true, simplification: false),
            appPunctuation: true))
        #expect(options.sharedPunctuation == false)
    }

    @Test func asciiStateFollowsItsScopeAndPublishesOnRemember() {
        var options = InputOptions()
        options.setAsciiScope(.app)
        let first = context(
            current: .init(asciiMode: true, asciiPunct: false, simplification: false),
            app: "com.example.terminal", appDefault: false, newSession: true)
        #expect(options.desired(for: first).asciiMode == false)
        options.remember(context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: false),
            app: "com.example.terminal", appDefault: false))

        let next = context(
            current: .init(asciiMode: true, asciiPunct: false, simplification: false),
            app: "com.example.terminal", appDefault: false)
        #expect(options.desired(for: next).asciiMode == false)
    }

    @Test func capsLockIsUndoneOnlyRightAfterThePress() {
        var options = InputOptions()
        let press = Date(timeIntervalSinceReferenceDate: 100)
        options.capsLockPressed(asciiBefore: false, at: press)
        #expect(options.undoCapsLockSwitch(currentAscii: true, at: press.addingTimeInterval(0.1)) == false)
        #expect(options.undoCapsLockSwitch(currentAscii: true, at: press.addingTimeInterval(0.1)) == nil)

        options.capsLockPressed(asciiBefore: false, at: press)
        #expect(options.undoCapsLockSwitch(currentAscii: false, at: press) == nil)
        options.capsLockPressed(asciiBefore: false, at: press)
        #expect(options.undoCapsLockSwitch(currentAscii: true, at: press.addingTimeInterval(1)) == nil)
    }

    @Test func scriptOptionFollowsTheStoredMode() {
        var options = InputOptions()
        var features = HufuFeatures()
        features.scriptMode = .tradOnly
        let on = context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: false),
            features: features)
        #expect(options.desired(for: on).simplification == true)

        features.scriptMode = .mixed
        let off = context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: true),
            features: features)
        #expect(options.desired(for: off).simplification == false)
    }

    @Test func featurePunctuationAppliesOnlyAfterTheSentinelIsSeeded() {
        var options = InputOptions()
        options.punctuationFeatureChanged(true)
        #expect(options.sharedPunctuation == nil)

        _ = options.desired(for: context(
            current: .init(asciiMode: false, asciiPunct: false, simplification: false)))
        options.punctuationFeatureChanged(true)
        #expect(options.sharedPunctuation == true)
    }
}
