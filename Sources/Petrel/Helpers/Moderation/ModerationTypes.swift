import Foundation

/// Everything the moderation engine needs to know about the viewer.
public struct ModerationOptions: Sendable {
    /// The signed-in viewer, or `nil` when signed out.
    ///
    /// It decides what counts as "my own content" and whether labels that
    /// only apply to signed-out viewers (`!no-unauthenticated`) take effect.
    public var userDid: DID?

    /// The viewer's moderation settings.
    public var prefs: ModerationPrefs

    /// Custom label definitions, keyed by the labeler that publishes them.
    ///
    /// Build the values with ``Moderation/interpretLabelValueDefinitions(_:)``.
    /// A label value that has no entry here falls back to the built-in table.
    public var labelDefs: [DID: [InterpretedLabelValueDefinition]]

    /// Creates moderation options.
    public init(
        userDid: DID?,
        prefs: ModerationPrefs,
        labelDefs: [DID: [InterpretedLabelValueDefinition]] = [:]
    ) {
        self.userDid = userDid
        self.prefs = prefs
        self.labelDefs = labelDefs
    }
}

/// Who is responsible for a moderation cause.
public enum ModerationCauseSource: Sendable, Hashable {
    /// The viewer's own action (a block, a mute, a hidden post), or a self-label.
    case user
    /// A moderation list the viewer subscribes to.
    case list(AppBskyGraphDefs.ListViewBasic)
    /// A labeler the viewer subscribes to.
    case labeler(DID)
}

/// A muted word that matched some text.
public struct MuteWordMatch: Sendable, Hashable {
    /// The muted word preference that matched.
    public var word: AppBskyActorDefs.MutedWord
    /// The text that matched it.
    public var predicate: String

    /// Creates a match.
    public init(word: AppBskyActorDefs.MutedWord, predicate: String) {
        self.word = word
        self.predicate = predicate
    }
}

/// One reason a subject is moderated.
public struct ModerationCause: Sendable, Hashable {
    /// The details of a cause that comes from a label.
    public struct LabelCause: Sendable, Hashable {
        /// The label that was applied.
        public var label: ComAtprotoLabelDefs.Label
        /// The definition the label value resolved to.
        public var labelDef: InterpretedLabelValueDefinition
        /// What the label is attached to.
        public var target: LabelTarget
        /// The effective preference after applying the viewer's settings.
        public var setting: LabelPreference
        /// The behavior of the definition for this target.
        public var behavior: ModerationBehavior
        /// Whether blurs caused by this label cannot be clicked through.
        public var noOverride: Bool

        /// Creates label cause details.
        public init(
            label: ComAtprotoLabelDefs.Label,
            labelDef: InterpretedLabelValueDefinition,
            target: LabelTarget,
            setting: LabelPreference,
            behavior: ModerationBehavior,
            noOverride: Bool
        ) {
            self.label = label
            self.labelDef = labelDef
            self.target = target
            self.setting = setting
            self.behavior = behavior
            self.noOverride = noOverride
        }
    }

    /// The kind of cause, with its details.
    public enum Kind: Sendable, Hashable {
        /// The viewer blocks the account.
        case blocking
        /// The account blocks the viewer.
        case blockedBy
        /// The subject involves a block between two other accounts.
        case blockOther
        /// A label applies.
        case label(LabelCause)
        /// The viewer muted the account.
        case muted
        /// The content matches one or more muted words.
        case muteWord([MuteWordMatch])
        /// The viewer hid the post.
        case hidden
    }

    /// The kind of cause without its details, named as in the reference implementation.
    public enum CauseType: String, Sendable, Hashable, CaseIterable {
        /// The viewer blocks the account.
        case blocking
        /// The account blocks the viewer.
        case blockedBy = "blocked-by"
        /// The subject involves a block between two other accounts.
        case blockOther = "block-other"
        /// A label applies.
        case label
        /// The viewer muted the account.
        case muted
        /// The content matches a muted word.
        case muteWord = "mute-word"
        /// The viewer hid the post.
        case hidden
    }

    /// The kind of cause, with its details.
    public var kind: Kind
    /// Who is responsible for the cause.
    public var source: ModerationCauseSource
    /// Sort order among causes: lower numbers are shown first.
    public var priority: Int
    /// Whether the cause comes from embedded content (a quoted post). A
    /// downgraded cause can filter the subject out of listings but does not
    /// blur or annotate it.
    public var downgraded: Bool

    /// Creates a cause.
    public init(kind: Kind, source: ModerationCauseSource, priority: Int, downgraded: Bool = false) {
        self.kind = kind
        self.source = source
        self.priority = priority
        self.downgraded = downgraded
    }

    /// The kind of cause without its details.
    public var type: CauseType {
        switch kind {
        case .blocking: return .blocking
        case .blockedBy: return .blockedBy
        case .blockOther: return .blockOther
        case .label: return .label
        case .muted: return .muted
        case .muteWord: return .muteWord
        case .hidden: return .hidden
        }
    }

    /// The label details, when this cause is a label.
    public var labelCause: LabelCause? {
        if case let .label(cause) = kind { return cause }
        return nil
    }

    /// The muted word matches, when this cause is a muted word; otherwise empty.
    public var matches: [MuteWordMatch] {
        if case let .muteWord(matches) = kind { return matches }
        return []
    }

    /// Whether this is a block in any direction.
    public var isBlock: Bool {
        switch kind {
        case .blocking, .blockedBy, .blockOther: return true
        default: return false
        }
    }
}

/// What to do with a subject in one UI context.
///
/// Obtained from ``ModerationDecision/ui(_:)``.
public struct ModerationUI: Sendable, Hashable {
    /// Whether the user must not be offered a way to reveal blurred content.
    public var noOverride: Bool
    /// Causes for leaving the subject out of a listing entirely.
    public var filters: [ModerationCause]
    /// Causes for covering the subject.
    public var blurs: [ModerationCause]
    /// Causes for showing a prominent warning.
    public var alerts: [ModerationCause]
    /// Causes for showing an informational notice.
    public var informs: [ModerationCause]

    /// Creates a UI decision.
    public init(
        noOverride: Bool = false,
        filters: [ModerationCause] = [],
        blurs: [ModerationCause] = [],
        alerts: [ModerationCause] = [],
        informs: [ModerationCause] = []
    ) {
        self.noOverride = noOverride
        self.filters = filters
        self.blurs = blurs
        self.alerts = alerts
        self.informs = informs
    }

    /// Whether the subject should be left out of the listing.
    public var filter: Bool {
        !filters.isEmpty
    }

    /// Whether the subject should be covered.
    public var blur: Bool {
        !blurs.isEmpty
    }

    /// Whether a prominent warning should be shown.
    public var alert: Bool {
        !alerts.isEmpty
    }

    /// Whether an informational notice should be shown.
    public var inform: Bool {
        !informs.isEmpty
    }
}

// MARK: - Subjects

/// A profile view the moderation engine can evaluate.
///
/// The generated profile views conform: `AppBskyActorDefs.ProfileViewBasic`,
/// `ProfileView`, `ProfileViewDetailed` and `ChatBskyActorDefs.ProfileViewBasic`.
public protocol ModerationSubjectProfile: Sendable {
    /// The account's DID.
    var did: DID { get }
    /// The viewer's relationship to the account (mutes and blocks).
    var viewer: AppBskyActorDefs.ViewerState? { get }
    /// Labels on the account and on its profile record.
    var labels: [ComAtprotoLabelDefs.Label]? { get }
    /// The account's status record view, if the profile view carries one.
    var moderationStatus: AppBskyActorDefs.StatusView? { get }
}

extension AppBskyActorDefs.ProfileViewBasic: ModerationSubjectProfile {
    public var moderationStatus: AppBskyActorDefs.StatusView? {
        status
    }
}

extension AppBskyActorDefs.ProfileView: ModerationSubjectProfile {
    public var moderationStatus: AppBskyActorDefs.StatusView? {
        status
    }
}

extension AppBskyActorDefs.ProfileViewDetailed: ModerationSubjectProfile {
    public var moderationStatus: AppBskyActorDefs.StatusView? {
        status
    }
}

extension ChatBskyActorDefs.ProfileViewBasic: ModerationSubjectProfile {
    public var moderationStatus: AppBskyActorDefs.StatusView? {
        nil
    }
}

/// A user list view the moderation engine can evaluate.
///
/// `AppBskyGraphDefs.ListViewBasic` and `AppBskyGraphDefs.ListView` conform.
public protocol ModerationSubjectUserList: Sendable {
    /// The list's AT URI. Its authority identifies the creator when no creator view is present.
    var uri: ATProtocolURI { get }
    /// Labels on the list.
    var labels: [ComAtprotoLabelDefs.Label]? { get }
    /// The list creator's profile, when the view includes it.
    var moderationCreator: AppBskyActorDefs.ProfileView? { get }
}

extension AppBskyGraphDefs.ListViewBasic: ModerationSubjectUserList {
    public var moderationCreator: AppBskyActorDefs.ProfileView? {
        nil
    }
}

extension AppBskyGraphDefs.ListView: ModerationSubjectUserList {
    public var moderationCreator: AppBskyActorDefs.ProfileView? {
        creator
    }
}
