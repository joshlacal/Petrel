import Foundation

/// The outcome of evaluating a subject against the viewer's moderation settings.
///
/// A decision is a list of ``ModerationCause`` values. Ask it what to do in a
/// particular place in the interface with ``ui(_:)``:
///
/// ```swift
/// let decision = Moderation.moderatePost(postView, options: options)
/// let list = decision.ui(.contentList)
/// if list.filter { /* leave the post out of the feed */ }
/// if list.blur { /* cover it; offer "Show" unless list.noOverride */ }
/// ```
public struct ModerationDecision: Sendable, Hashable {
    /// The account the subject belongs to, when known.
    public var did: DID?
    /// Whether the subject belongs to the viewer.
    public var isMe: Bool
    /// Every reason the subject is moderated, in the order they were found.
    public var causes: [ModerationCause]

    /// Creates a decision.
    public init(did: DID? = nil, isMe: Bool = false, causes: [ModerationCause] = []) {
        self.did = did
        self.isMe = isMe
        self.causes = causes
    }

    // MARK: Combining

    /// Combines several decisions into one.
    ///
    /// The result takes `did` and `isMe` from the first non-`nil` decision and
    /// concatenates the causes of all of them in order.
    public static func merge(_ decisions: ModerationDecision?...) -> ModerationDecision {
        merge(decisions)
    }

    /// Combines an array of decisions into one, with the same rules as the variadic form.
    public static func merge(_ decisions: [ModerationDecision?]) -> ModerationDecision {
        let present = decisions.compactMap { $0 }
        var merged = ModerationDecision()
        if let first = present.first {
            merged.did = first.did
            merged.isMe = first.isMe
        }
        merged.causes = present.flatMap(\.causes)
        return merged
    }

    /// Marks every cause as coming from embedded content.
    public mutating func downgrade() {
        for index in causes.indices {
            causes[index].downgraded = true
        }
    }

    /// A copy of this decision with every cause marked as coming from embedded content.
    public func downgraded() -> ModerationDecision {
        var copy = self
        copy.downgrade()
        return copy
    }

    // MARK: Inspection

    /// Whether a block in either direction applies.
    public var blocked: Bool {
        blockCause != nil
    }

    /// Whether the account is muted.
    public var muted: Bool {
        muteCause != nil
    }

    /// The first block cause, if any.
    public var blockCause: ModerationCause? {
        causes.first { $0.isBlock }
    }

    /// The first mute cause, if any.
    public var muteCause: ModerationCause? {
        causes.first { $0.type == .muted }
    }

    /// Every cause that comes from a label.
    public var labelCauses: [ModerationCause] {
        causes.filter { $0.type == .label }
    }

    // MARK: UI

    /// What to do with the subject in one UI context.
    ///
    /// Filters and blurs are ordered by priority, most important first.
    public func ui(_ context: ModerationBehavior.Context) -> ModerationUI {
        var ui = ModerationUI()
        let isListing = context == .profileList || context == .contentList

        func apply(_ action: ModerationBehavior.Action?, _ cause: ModerationCause, noOverride: Bool = false) {
            switch action {
            case .blur:
                ui.blurs.append(cause)
                if noOverride {
                    ui.noOverride = true
                }
            case .alert:
                ui.alerts.append(cause)
            case .inform:
                ui.informs.append(cause)
            case nil:
                break
            }
        }

        for cause in causes {
            switch cause.kind {
            case .blocking, .blockedBy, .blockOther:
                if isMe { continue }
                if isListing {
                    ui.filters.append(cause)
                }
                if !cause.downgraded {
                    apply(ModerationBehavior.block[context], cause, noOverride: true)
                }
            case .muted:
                if isMe { continue }
                if isListing {
                    ui.filters.append(cause)
                }
                if !cause.downgraded {
                    apply(ModerationBehavior.mute[context], cause)
                }
            case .muteWord:
                if isMe { continue }
                if context == .contentList {
                    ui.filters.append(cause)
                }
                if !cause.downgraded {
                    apply(ModerationBehavior.muteWord[context], cause)
                }
            case .hidden:
                if isListing {
                    ui.filters.append(cause)
                }
                if !cause.downgraded {
                    apply(ModerationBehavior.hide[context], cause)
                }
            case let .label(label):
                let filtersHere = (context == .profileList && label.target == .account)
                    || (context == .contentList && (label.target == .account || label.target == .content))
                if filtersHere, label.setting == .hide, !isMe {
                    ui.filters.append(cause)
                }
                if !cause.downgraded {
                    apply(label.behavior[context], cause, noOverride: label.noOverride && !isMe)
                }
            }
        }

        ui.filters = Self.sortedByPriority(ui.filters)
        ui.blurs = Self.sortedByPriority(ui.blurs)
        return ui
    }

    /// Orders causes by ascending priority, keeping the original order among equals.
    private static func sortedByPriority(_ causes: [ModerationCause]) -> [ModerationCause] {
        causes.enumerated()
            .sorted { lhs, rhs in
                lhs.element.priority != rhs.element.priority
                    ? lhs.element.priority < rhs.element.priority
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    // MARK: Adding causes

    /// Adds a "hidden by the viewer" cause when `hidden` is true.
    public mutating func addHidden(_ hidden: Bool) {
        if hidden {
            causes.append(ModerationCause(kind: .hidden, source: .user, priority: 6))
        }
    }

    /// Adds a muted-word cause when `matches` is not empty.
    public mutating func addMutedWord(_ matches: [MuteWordMatch]) {
        if !matches.isEmpty {
            causes.append(ModerationCause(kind: .muteWord(matches), source: .user, priority: 6))
        }
    }

    /// Adds a "viewer blocks the account" cause when `blocking` is true.
    public mutating func addBlocking(_ blocking: Bool) {
        if blocking {
            causes.append(ModerationCause(kind: .blocking, source: .user, priority: 3))
        }
    }

    /// Adds a "viewer blocks the account through a list" cause.
    public mutating func addBlockingByList(_ list: AppBskyGraphDefs.ListViewBasic?) {
        if let list {
            causes.append(ModerationCause(kind: .blocking, source: .list(list), priority: 3))
        }
    }

    /// Adds an "account blocks the viewer" cause when `blockedBy` is true.
    public mutating func addBlockedBy(_ blockedBy: Bool) {
        if blockedBy {
            causes.append(ModerationCause(kind: .blockedBy, source: .user, priority: 4))
        }
    }

    /// Adds a "block between two other accounts" cause when `blockOther` is true.
    public mutating func addBlockOther(_ blockOther: Bool) {
        if blockOther {
            causes.append(ModerationCause(kind: .blockOther, source: .user, priority: 4))
        }
    }

    /// Adds a "viewer muted the account" cause when `muted` is true.
    public mutating func addMuted(_ muted: Bool) {
        if muted {
            causes.append(ModerationCause(kind: .muted, source: .user, priority: 6))
        }
    }

    /// Adds a "viewer muted the account through a list" cause.
    public mutating func addMutedByList(_ list: AppBskyGraphDefs.ListViewBasic?) {
        if let list {
            causes.append(ModerationCause(kind: .muted, source: .list(list), priority: 6))
        }
    }

    /// Evaluates one label and adds a cause for it if it applies to the viewer.
    ///
    /// A label is dropped when its value has no definition, when it comes from
    /// a labeler the viewer does not subscribe to (self-labels excepted), when
    /// it is a self-label of a value that does not permit self-labeling, when
    /// the effective preference is ``LabelPreference/ignore``, or when it only
    /// applies to signed-out viewers and the viewer is signed in.
    ///
    /// - Parameters:
    ///   - target: What the label is attached to.
    ///   - label: The label.
    ///   - options: The viewer's settings and the custom label definitions.
    public mutating func addLabel(
        _ target: LabelTarget,
        _ label: ComAtprotoLabelDefs.Label,
        options: ModerationOptions
    ) {
        // Look up the label definition. Only syntactically valid custom values
        // may be defined by a labeler; everything else must be built in.
        let builtIn = KnownLabels.definitions[label.val]
        let definition: InterpretedLabelValueDefinition?
        if Self.isCustomLabelValue(label.val) {
            definition = options.labelDefs[label.src]?.first { $0.identifier == label.val } ?? builtIn
        } else {
            definition = builtIn
        }
        guard let labelDef = definition else {
            return // ignore labels we don't understand
        }

        // Look up the label preference.
        let isSelf = label.src == did
        let labeler = isSelf ? nil : options.prefs.labelers.first { $0.did == label.src }
        if !isSelf, labeler == nil {
            return // skip labelers not configured by the user
        }
        if isSelf, labelDef.flags.contains(.noSelf) {
            return // skip self-labels that aren't supported
        }

        let isAdultGated = labelDef.flags.contains(.adult) && !options.prefs.adultContentEnabled

        var setting = labelDef.defaultSetting
        if !labelDef.configurable {
            setting = labelDef.defaultSetting
        } else if isAdultGated {
            setting = .hide
        } else if let labelerSetting = labeler?.labels[labelDef.identifier] {
            setting = labelerSetting
        } else if let globalSetting = options.prefs.labels[labelDef.identifier] {
            setting = globalSetting
        }

        if setting == .ignore {
            return // the user asked to ignore this label
        }
        if labelDef.flags.contains(.unauthed), options.userDid != nil {
            return // only applies to signed-out viewers
        }

        let behavior = labelDef.behaviors[target]
        let noOverride = labelDef.flags.contains(.noOverride) || isAdultGated

        let priority: Int
        if noOverride {
            priority = 1
        } else if setting == .hide {
            priority = 2
        } else if behavior.profileView == .blur || behavior.contentView == .blur {
            priority = 5 // blurring a whole profile or content screen
        } else if behavior.contentList == .blur || behavior.contentMedia == .blur {
            priority = 7 // blurring content in a list, or its media
        } else {
            priority = 8 // blurring an avatar, adding alerts
        }

        let source: ModerationCauseSource
        if let labeler, !isSelf {
            source = .labeler(labeler.did)
        } else {
            source = .user
        }

        causes.append(
            ModerationCause(
                kind: .label(
                    ModerationCause.LabelCause(
                        label: label,
                        labelDef: labelDef,
                        target: target,
                        setting: setting,
                        behavior: behavior,
                        noOverride: noOverride
                    )
                ),
                source: source,
                priority: priority
            )
        )
    }

    /// Whether `value` is syntactically a custom label value: one or more of `a-z` and `-`.
    static func isCustomLabelValue(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { ($0 >= 0x61 && $0 <= 0x7A) || $0 == 0x2D }
    }
}
