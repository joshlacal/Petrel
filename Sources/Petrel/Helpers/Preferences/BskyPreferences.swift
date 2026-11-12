import Foundation

/// How a feed should filter what it shows (`app.bsky.actor.defs#feedViewPref`),
/// with every field resolved to a value.
public struct BskyFeedViewPreference: Sendable, Hashable {
    /// Hide all replies.
    public var hideReplies: Bool
    /// Hide replies whose author the user does not follow.
    public var hideRepliesByUnfollowed: Bool
    /// Hide replies with fewer likes than this.
    public var hideRepliesByLikeCount: Int
    /// Hide reposts.
    public var hideReposts: Bool
    /// Hide quote posts.
    public var hideQuotePosts: Bool

    /// Creates a feed view preference. The defaults are the ones the official client applies.
    public init(
        hideReplies: Bool = false,
        hideRepliesByUnfollowed: Bool = true,
        hideRepliesByLikeCount: Int = 0,
        hideReposts: Bool = false,
        hideQuotePosts: Bool = false
    ) {
        self.hideReplies = hideReplies
        self.hideRepliesByUnfollowed = hideRepliesByUnfollowed
        self.hideRepliesByLikeCount = hideRepliesByLikeCount
        self.hideReposts = hideReposts
        self.hideQuotePosts = hideQuotePosts
    }
}

/// A partial change to a feed's view preference. Fields left `nil` keep their stored value.
public struct BskyFeedViewPreferenceUpdate: Sendable, Hashable {
    /// Hide all replies.
    public var hideReplies: Bool?
    /// Hide replies whose author the user does not follow.
    public var hideRepliesByUnfollowed: Bool?
    /// Hide replies with fewer likes than this.
    public var hideRepliesByLikeCount: Int?
    /// Hide reposts.
    public var hideReposts: Bool?
    /// Hide quote posts.
    public var hideQuotePosts: Bool?

    /// Creates an update that changes only the fields given.
    public init(
        hideReplies: Bool? = nil,
        hideRepliesByUnfollowed: Bool? = nil,
        hideRepliesByLikeCount: Int? = nil,
        hideReposts: Bool? = nil,
        hideQuotePosts: Bool? = nil
    ) {
        self.hideReplies = hideReplies
        self.hideRepliesByUnfollowed = hideRepliesByUnfollowed
        self.hideRepliesByLikeCount = hideRepliesByLikeCount
        self.hideReposts = hideReposts
        self.hideQuotePosts = hideQuotePosts
    }
}

/// How threads are displayed (`app.bsky.actor.defs#threadViewPref`).
public struct BskyThreadViewPreference: Sendable, Hashable {
    /// Reply sort order: `oldest`, `newest`, `most-likes`, `random` or `hotness`.
    public var sort: String

    /// Creates a thread view preference. `hotness` is the official client's default.
    public init(sort: String = "hotness") {
        self.sort = sort
    }
}

/// The topics the user picked during onboarding (`app.bsky.actor.defs#interestsPref`).
public struct BskyInterestsPreference: Sendable, Hashable {
    /// Interest tags.
    public var tags: [String]

    /// Creates an interests preference.
    public init(tags: [String] = []) {
        self.tags = tags
    }
}

/// The onboarding guide the user is working through
/// (`app.bsky.actor.defs#bskyAppProgressGuide`).
public struct BskyAppProgressGuide: Sendable, Hashable {
    /// The guide's identifier.
    public var guide: String

    /// Fields stored next to `guide` that the lexicon does not describe. The
    /// official client keeps its progress counters here.
    public var additionalFields: [String: ATProtocolValueContainer]

    /// Creates a progress guide value.
    public init(guide: String, additionalFields: [String: ATProtocolValueContainer] = [:]) {
        self.guide = guide
        self.additionalFields = additionalFields
    }
}

/// State the official Bluesky app keeps in preferences
/// (`app.bsky.actor.defs#bskyAppStatePref`).
public struct BskyAppState: Sendable, Hashable {
    /// Nudges waiting to be shown.
    public var queuedNudges: [String]
    /// The onboarding guide in progress, if any.
    public var activeProgressGuide: BskyAppProgressGuide?
    /// New-user-experience items and whether each was completed.
    public var nuxs: [AppBskyActorDefs.Nux]
    /// Whether the user joined the beta program. `nil` when never set.
    public var isBetaUser: Bool?

    /// Creates app state.
    public init(
        queuedNudges: [String] = [],
        activeProgressGuide: BskyAppProgressGuide? = nil,
        nuxs: [AppBskyActorDefs.Nux] = [],
        isBetaUser: Bool? = nil
    ) {
        self.queuedNudges = queuedNudges
        self.activeProgressGuide = activeProgressGuide
        self.nuxs = nuxs
        self.isBetaUser = isBetaUser
    }
}

/// Which live-event feeds are hidden (`app.bsky.actor.defs#liveEventPreferences`).
public struct BskyLiveEventPreferences: Sendable, Hashable {
    /// Identifiers of hidden live-event feeds.
    public var hiddenFeedIds: [String]
    /// Whether every live-event feed is hidden.
    public var hideAllFeeds: Bool

    /// Creates live-event preferences.
    public init(hiddenFeedIds: [String] = [], hideAllFeeds: Bool = false) {
        self.hiddenFeedIds = hiddenFeedIds
        self.hideAllFeeds = hideAllFeeds
    }
}

/// A change to the live-event preferences.
public enum BskyLiveEventPreferencesAction: Sendable, Hashable {
    /// Hide one live-event feed.
    case hideFeed(id: String)
    /// Show one live-event feed again.
    case unhideFeed(id: String)
    /// Flip whether all live-event feeds are hidden.
    case toggleHideAllFeeds
}

/// A feed to save, before it has been given an identifier.
public struct BskyNewSavedFeed: Sendable, Hashable {
    /// `feed`, `list` or `timeline`.
    public var type: String
    /// An AT URI for `feed` and `list`; `following` for `timeline`.
    public var value: String
    /// Whether the feed is pinned to the home screen.
    public var pinned: Bool

    /// Creates a saved-feed description.
    public init(type: String, value: String, pinned: Bool) {
        self.type = type
        self.value = value
        self.pinned = pinned
    }

    /// A feed generator (`app.bsky.feed.generator` record).
    public static func feed(_ uri: ATProtocolURI, pinned: Bool) -> BskyNewSavedFeed {
        BskyNewSavedFeed(type: "feed", value: uri.uriString(), pinned: pinned)
    }

    /// A list (`app.bsky.graph.list` record) shown as a feed.
    public static func list(_ uri: ATProtocolURI, pinned: Bool) -> BskyNewSavedFeed {
        BskyNewSavedFeed(type: "list", value: uri.uriString(), pinned: pinned)
    }

    /// A built-in timeline. `following` is the only one defined today.
    public static func timeline(_ name: String = "following", pinned: Bool) -> BskyNewSavedFeed {
        BskyNewSavedFeed(type: "timeline", value: name, pinned: pinned)
    }
}

/// The account's Bluesky preferences, parsed into one value.
///
/// Returned by ``BskyAgent/getPreferences()``. Stored preferences are a list
/// of loosely related entries; this type resolves duplicates (the last valid
/// entry of a kind wins), fills in the defaults the official client uses, and
/// maps legacy entries onto their current form.
public struct BskyPreferences: Sendable, Hashable {
    /// The first-generation saved feeds entry (`savedFeedsPref`).
    public struct LegacyFeeds: Sendable, Hashable {
        /// Saved feeds, or `nil` when the account has no first-generation entry.
        public var saved: [ATProtocolURI]?
        /// Pinned feeds, or `nil` when the account has no first-generation entry.
        public var pinned: [ATProtocolURI]?

        /// Creates a legacy feeds value.
        public init(saved: [ATProtocolURI]? = nil, pinned: [ATProtocolURI]? = nil) {
            self.saved = saved
            self.pinned = pinned
        }
    }

    /// First-generation saved feeds. Read ``savedFeeds`` instead; this exists
    /// for clients that still need the old shape.
    public var feeds: LegacyFeeds
    /// Saved and pinned feeds, pinned first.
    public var savedFeeds: [AppBskyActorDefs.SavedFeed]
    /// View preferences per feed. `home` is always present.
    public var feedViewPrefs: [String: BskyFeedViewPreference]
    /// Thread display preferences.
    public var threadViewPrefs: BskyThreadViewPreference
    /// Moderation settings, ready to hand to the moderation decision engine.
    public var moderationPrefs: ModerationPrefs
    /// The birth date the user declared, if any.
    public var birthDate: Date?
    /// Age brackets the server derived from the declared birth date. Read-only;
    /// `nil` when no birth date was declared.
    public var declaredAge: AppBskyActorDefs.DeclaredAgePref?
    /// Onboarding interests.
    public var interests: BskyInterestsPreference
    /// State kept by the official app.
    public var bskyAppState: BskyAppState
    /// Default reply and quote restrictions for new posts. A `nil` rule list
    /// means "no restriction".
    public var postInteractionSettings: AppBskyActorDefs.PostInteractionSettingsPref
    /// Verification display preferences.
    public var verificationPrefs: AppBskyActorDefs.VerificationPrefs
    /// Live-event feed preferences.
    public var liveEventPreferences: BskyLiveEventPreferences

    /// Creates a preferences value. The defaults are those of an account that
    /// has stored nothing.
    public init(
        feeds: LegacyFeeds = LegacyFeeds(),
        savedFeeds: [AppBskyActorDefs.SavedFeed] = [],
        feedViewPrefs: [String: BskyFeedViewPreference] = ["home": BskyFeedViewPreference()],
        threadViewPrefs: BskyThreadViewPreference = BskyThreadViewPreference(),
        moderationPrefs: ModerationPrefs = ModerationPrefs(),
        birthDate: Date? = nil,
        declaredAge: AppBskyActorDefs.DeclaredAgePref? = nil,
        interests: BskyInterestsPreference = BskyInterestsPreference(),
        bskyAppState: BskyAppState = BskyAppState(),
        postInteractionSettings: AppBskyActorDefs.PostInteractionSettingsPref = AppBskyActorDefs.PostInteractionSettingsPref(),
        verificationPrefs: AppBskyActorDefs.VerificationPrefs = AppBskyActorDefs.VerificationPrefs(hideBadges: false),
        liveEventPreferences: BskyLiveEventPreferences = BskyLiveEventPreferences()
    ) {
        self.feeds = feeds
        self.savedFeeds = savedFeeds
        self.feedViewPrefs = feedViewPrefs
        self.threadViewPrefs = threadViewPrefs
        self.moderationPrefs = moderationPrefs
        self.birthDate = birthDate
        self.declaredAge = declaredAge
        self.interests = interests
        self.bskyAppState = bskyAppState
        self.postInteractionSettings = postInteractionSettings
        self.verificationPrefs = verificationPrefs
        self.liveEventPreferences = liveEventPreferences
    }
}
