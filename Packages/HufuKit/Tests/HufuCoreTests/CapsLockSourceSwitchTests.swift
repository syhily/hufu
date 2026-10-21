import Foundation
import Testing
@testable import HufuCore

struct CapsLockSourceSwitchTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// Chinese, Caps Lock switches to ABC: the English state librime set on the way out
    /// is undone, so switching back lands in Chinese.
    @Test func switchingAwayUndoesTheToggle() {
        var caps = CapsLockSourceSwitch()
        caps.pressed(asciiBefore: false, at: t0)
        #expect(caps.deactivated(at: t0.addingTimeInterval(0.02)) == false)
    }

    @Test func switchingAwayFromEnglishKeepsEnglish() {
        var caps = CapsLockSourceSwitch()
        caps.pressed(asciiBefore: true, at: t0)
        #expect(caps.deactivated(at: t0.addingTimeInterval(0.02)) == true)
    }

    /// Caps Lock used as Hufu's own 中/英 key, then the user moves on later.
    @Test func ordinaryToggleIsKept() {
        var caps = CapsLockSourceSwitch()
        caps.pressed(asciiBefore: false, at: t0)
        #expect(caps.deactivated(at: t0.addingTimeInterval(CapsLockSourceSwitch.pressToDeactivate)) == nil)
    }

    @Test func deactivationWithoutPressKeepsState() {
        var caps = CapsLockSourceSwitch()
        #expect(caps.deactivated(at: t0) == nil)
    }

    /// A press is undone at most once: the next deactivation keeps whatever state follows.
    @Test func pressIsForgottenAfterDeactivation() {
        var caps = CapsLockSourceSwitch()
        caps.pressed(asciiBefore: false, at: t0)
        #expect(caps.deactivated(at: t0.addingTimeInterval(5)) == nil)
        #expect(caps.deactivated(at: t0.addingTimeInterval(5.01)) == nil)
    }
}
