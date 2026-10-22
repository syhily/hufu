import Foundation
import Testing
@testable import HufuCore
@testable import HufuPanel

struct CandidatePresentationTests {
    /// Same stand-in tables as ScriptModeTests: 马/发/为/龙 have traditional forms,
    /// 龙 is not itself standard.
    private let filter = ScriptFilter(
        conversions: ["马": ["馬"], "发": ["發", "髮"], "为": ["爲", "為"], "龙": ["龍"],
                      "个": ["個"], "你": ["你", "妳"]],
        common: ["一", "马", "发", "为", "好", "你", "中", "国", "个"]
    )

    private func normalInput(_ candidates: [String], labels: [String] = []) -> CandidatePresentation.Input {
        CandidatePresentation.Input(
            preedit: "ma",
            preeditSelection: NSRange(location: 0, length: 1),
            input: "ma",
            candidates: candidates.map { .init(text: $0) },
            labels: labels,
            highlightedIndex: 0,
            pageNumber: 2,
            isLastPage: false,
            pageSize: 5,
            scriptMode: .mixed,
            traditional: false,
            showsMenuButton: true
        )
    }

    @Test func normalPagePassesThrough() {
        var presentation = CandidatePresentation()
        let state = presentation.present(normalInput(["你", "泥"], labels: ["1", "2"]))
        #expect(state.preedit == "ma")
        #expect(state.candidates.map(\.text) == ["你", "泥"])
        #expect(state.candidates.map(\.label) == ["1", "2"])
        #expect(state.highlightedIndex == 0)
        #expect(state.pageNumber == 2)
        #expect(state.isLastPage == false)
        #expect(state.showsMenuButton == true)
        #expect(presentation.isRearranged == false)
        #expect(presentation.selection(forDisplayIndex: 1) == .rime(index: 1))
    }

    @Test func mixedModeReordersAndMapsSelection() {
        var presentation = CandidatePresentation(scriptFilter: filter)
        let state = presentation.present(normalInput(["馬", "你"]))
        #expect(state.candidates.map(\.text) == ["你", "馬"])
        #expect(state.candidates.map(\.label) == ["1", "2"])
        #expect(state.highlightedIndex == 1)
        #expect(presentation.isRearranged == true)
        #expect(presentation.highlightedDisplayIndex == 1)
        #expect(presentation.selection(forDisplayIndex: 0) == .rime(index: 1))
        #expect(presentation.selection(forDisplayIndex: 1) == .rime(index: 0))
    }

    @Test func filteredModeDropsAndRenumbers() {
        var presentation = CandidatePresentation(scriptFilter: filter)
        var input = normalInput(["马", "馬", "好"])
        input.scriptMode = .tradOnly
        input.traditional = true
        let state = presentation.present(input)
        #expect(state.candidates.map(\.text) == ["馬", "好"])
        #expect(state.candidates.map(\.label) == ["1", "2"])
        #expect(presentation.selection(forDisplayIndex: 0) == .rime(index: 1))
        #expect(presentation.selection(forDisplayIndex: 1) == .rime(index: 2))
    }

    @Test func emptyFilteredPageSelectsNothing() {
        var presentation = CandidatePresentation(scriptFilter: filter)
        var input = normalInput(["龘"])
        input.scriptMode = .simpOnly
        input.traditional = false
        let state = presentation.present(input)
        #expect(state.candidates.isEmpty)
        #expect(presentation.isRearranged == true)
        #expect(presentation.selection(forDisplayIndex: 0) == .none)
    }

    @Test func specialInputReplacesThePageAndKeepsItsOwnPage() throws {
        var presentation = CandidatePresentation()
        let expected = try #require(SpecialInput.candidates(for: "/1234"))
        var input = normalInput([])
        input.input = "/1234"
        input.pageSize = 1
        input.candidates = []

        let first = presentation.present(input)
        #expect(presentation.hasSpecialCandidates)
        #expect(presentation.specialPageCount == expected.count)
        #expect(first.candidates.map(\.text) == [expected[0].text])
        #expect(first.candidates.map(\.label) == ["1"])
        #expect(first.pageNumber == 0)
        #expect(first.isLastPage == false)
        #expect(presentation.selection(forDisplayIndex: 0) == .special(text: expected[0].text))

        #expect(presentation.action(for: "=", input: "/1234") == .page(backward: false))
        #expect(presentation.page(backward: false) == true)
        let second = presentation.present(input)
        #expect(second.pageNumber == 1)
        #expect(second.candidates.map(\.text) == [expected[1].text])
        #expect(presentation.selection(forDisplayIndex: 0) == .special(text: expected[1].text))

        input.input = "/12"
        let reset = presentation.present(input)
        #expect(reset.pageNumber == 0)
        #expect(presentation.specialPageCount > 1)
    }

    @Test func specialInputDisappearsWhenTheInputIsNoLongerSpecial() {
        var presentation = CandidatePresentation()
        var input = normalInput([])
        input.input = "/1234"
        input.pageSize = 1
        _ = presentation.present(input)
        #expect(presentation.hasSpecialCandidates)

        input.input = "ma"
        _ = presentation.present(input)
        #expect(presentation.hasSpecialCandidates == false)
        #expect(presentation.action(for: "=", input: "ma") == nil)
    }

    @Test func pageHandsNonSpecialKeysToRime() {
        var presentation = CandidatePresentation()
        _ = presentation.present(normalInput(["你"]))
        #expect(presentation.page(backward: true) == false)
    }
}
