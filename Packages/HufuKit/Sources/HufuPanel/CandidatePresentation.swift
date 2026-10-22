public import AppKit
public import HufuCore

/// What the candidate panel shows for one rime context, and what each display index
/// means. The controller hands in a snapshot of librime's menu; the module owns the
/// frontend candidates (便利功能), the 简繁 filter and the display→rime mapping.
public struct CandidatePresentation: Sendable {
    public struct CandidateText: Sendable, Equatable {
        public var text: String
        public var comment: String

        public init(text: String, comment: String = "") {
            self.text = text
            self.comment = comment
        }
    }

    public struct Input: Sendable {
        public var preedit: String
        public var preeditSelection: NSRange
        /// The raw rime input (what `SpecialInput` reads).
        public var input: String
        public var candidates: [CandidateText]
        public var labels: [String]
        public var highlightedIndex: Int
        public var pageNumber: Int
        public var isLastPage: Bool
        public var pageSize: Int
        public var specialOptions: SpecialInput.Options
        public var scriptMode: ScriptMode
        /// librime's live `simplification` option; ⌃O / ⌃⇧4 move it for the session.
        public var traditional: Bool
        public var showsMenuButton: Bool

        public init(
            preedit: String = "",
            preeditSelection: NSRange = NSRange(location: 0, length: 0),
            input: String = "",
            candidates: [CandidateText] = [],
            labels: [String] = [],
            highlightedIndex: Int = 0,
            pageNumber: Int = 0,
            isLastPage: Bool = true,
            pageSize: Int = 5,
            specialOptions: SpecialInput.Options = SpecialInput.Options(),
            scriptMode: ScriptMode = .mixed,
            traditional: Bool = false,
            showsMenuButton: Bool = false
        ) {
            self.preedit = preedit
            self.preeditSelection = preeditSelection
            self.input = input
            self.candidates = candidates
            self.labels = labels
            self.highlightedIndex = highlightedIndex
            self.pageNumber = pageNumber
            self.isLastPage = isLastPage
            self.pageSize = pageSize
            self.specialOptions = specialOptions
            self.scriptMode = scriptMode
            self.traditional = traditional
            self.showsMenuButton = showsMenuButton
        }
    }

    public enum Selection: Sendable, Equatable {
        /// One of the frontend's own candidates (`/time`, `=1+2`).
        case special(text: String)
        /// An index into librime's current page.
        case rime(index: Int)
        case none
    }

    private let scriptFilter: ScriptFilter
    private var specialCandidates: [SpecialInput.Candidate]?
    private var specialInput = ""
    private var specialPage = 0
    private var specialPageSize = 5
    private var specialOptions = SpecialInput.Options()
    /// displayIndex → rimeIndex for the page currently shown.
    private var scriptOrder: [Int] = []
    public private(set) var isRearranged = false
    /// Display position of librime's highlighted candidate while filtering.
    public private(set) var highlightedDisplayIndex = 0

    public init(scriptFilter: ScriptFilter = ScriptFilter(conversions: [:], common: [])) {
        self.scriptFilter = scriptFilter
    }

    /// Builds the panel state for one context and remembers the mapping `select` needs.
    public mutating func present(_ input: Input) -> PanelState {
        updateSpecialCandidates(for: input.input, pageSize: input.pageSize, options: input.specialOptions)
        updateScriptFilter(candidates: input.candidates.map(\.text), mode: input.scriptMode.resolved(traditional: input.traditional))

        if let visible = visibleSpecialCandidates, !visible.isEmpty {
            let candidates = visible.enumerated().map { offset, candidate in
                PanelState.Candidate(label: "\(offset + 1)", text: candidate.text, comment: candidate.comment)
            }
            return PanelState(
                preedit: input.preedit,
                preeditSelection: input.preeditSelection,
                candidates: candidates,
                highlightedIndex: 0,
                pageNumber: specialPage,
                isLastPage: specialPage >= specialPageCount - 1,
                showsMenuButton: input.showsMenuButton
            )
        }

        if isRearranged {
            let candidates = scriptOrder.enumerated().map { display, rime in
                let candidate = input.candidates[rime]
                return PanelState.Candidate(label: "\(display + 1)", text: candidate.text, comment: candidate.comment)
            }
            let highlighted = scriptOrder.firstIndex(of: input.highlightedIndex) ?? 0
            highlightedDisplayIndex = highlighted
            return PanelState(
                preedit: input.preedit,
                preeditSelection: input.preeditSelection,
                candidates: candidates,
                highlightedIndex: highlighted,
                pageNumber: input.pageNumber,
                isLastPage: input.isLastPage,
                showsMenuButton: input.showsMenuButton
            )
        }

        let candidates = input.candidates.enumerated().map { index, candidate in
            PanelState.Candidate(
                label: input.labels.indices.contains(index) ? input.labels[index] : "\(index + 1)",
                text: candidate.text,
                comment: candidate.comment
            )
        }
        return PanelState(
            preedit: input.preedit,
            preeditSelection: input.preeditSelection,
            candidates: candidates,
            highlightedIndex: input.highlightedIndex,
            pageNumber: input.pageNumber,
            isLastPage: input.isLastPage,
            showsMenuButton: input.showsMenuButton
        )
    }

    /// What choosing `index` on the visible page means.
    public func selection(forDisplayIndex index: Int) -> Selection {
        if let visible = visibleSpecialCandidates, !visible.isEmpty {
            guard visible.indices.contains(index) else { return .none }
            return .special(text: visible[index].text)
        }
        if isRearranged {
            guard scriptOrder.indices.contains(index) else { return .none }
            return .rime(index: scriptOrder[index])
        }
        return index >= 0 ? .rime(index: index) : .none
    }

    /// Moves the frontend page. Returns true when the key belonged to a special page
    /// (even if there was only one page); false hands it to librime.
    @discardableResult
    public mutating func page(backward: Bool) -> Bool {
        guard specialCandidates != nil else { return false }
        let pages = specialPageCount
        guard pages > 1 else { return true }
        specialPage = min(max(0, specialPage + (backward ? -1 : 1)), pages - 1)
        return true
    }

    /// The special-input action for a typed key, or nil when no special page is up.
    public func action(for character: Character, input: String) -> SpecialInput.Action? {
        guard hasSpecialCandidates else { return nil }
        return SpecialInput.action(for: character, input: input, pageCount: specialPageCount, options: specialOptions)
    }

    public var hasSpecialCandidates: Bool {
        !(specialCandidates?.isEmpty ?? true)
    }

    /// A filtered page where nothing survived. Selection keys must be swallowed rather
    /// than handed to librime, which still holds candidates the panel never showed.
    public var isEmptyFilteredPage: Bool { isRearranged && scriptOrder.isEmpty }

    public var visibleSpecialCandidates: [SpecialInput.Candidate]? {
        guard let candidates = specialCandidates, !candidates.isEmpty else { return nil }
        let start = min(specialPage * specialPageSize, candidates.count)
        return Array(candidates[start..<min(start + specialPageSize, candidates.count)])
    }

    public var specialPageCount: Int {
        guard let candidates = specialCandidates, !candidates.isEmpty else { return 0 }
        return (candidates.count + specialPageSize - 1) / specialPageSize
    }

    private mutating func updateSpecialCandidates(for input: String, pageSize: Int, options: SpecialInput.Options) {
        if input != specialInput {
            specialInput = input
            specialPage = 0
        }
        specialPageSize = max(1, pageSize)
        specialOptions = options
        specialCandidates = input.isEmpty ? nil : SpecialInput.candidates(for: input, options: options)
        if specialPage >= specialPageCount { specialPage = 0 }
    }

    private mutating func updateScriptFilter(candidates: [String], mode: ScriptMode) {
        let order = scriptFilter.order(candidates, mode: mode)
        scriptOrder = order
        isRearranged = order != Array(candidates.indices)
    }
}
