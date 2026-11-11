import Foundation

/// How the user wants content carrying a given label to be treated.
public enum LabelPreference: String, Sendable, Hashable, Codable, CaseIterable {
    /// Show the content as if the label were not there.
    case ignore
    /// Show the content behind a warning.
    case warn
    /// Remove the content from listings.
    case hide
}

/// A labeler the user subscribes to, with the user's per-label overrides for it.
public struct ModerationPrefsLabeler: Sendable, Hashable {
    /// The labeler service DID.
    public var did: DID
    /// The user's settings for this labeler's label values, keyed by label value.
    public var labels: [String: LabelPreference]

    /// Creates a labeler subscription.
    public init(did: DID, labels: [String: LabelPreference] = [:]) {
        self.did = did
        self.labels = labels
    }
}

/// The user's moderation settings, as consumed by the moderation decision engine.
///
/// ``BskyAgent/getPreferences()`` builds this from the account's stored
/// preferences; it can also be constructed directly.
public struct ModerationPrefs: Sendable, Hashable {
    /// Whether the user has opted in to adult content.
    public var adultContentEnabled: Bool
    /// Settings for the built-in (global) label values, keyed by label value.
    public var labels: [String: LabelPreference]
    /// The labelers whose labels apply. Labels from any other source are ignored.
    public var labelers: [ModerationPrefsLabeler]
    /// Words and tags the user has muted.
    public var mutedWords: [AppBskyActorDefs.MutedWord]
    /// Posts the user has hidden.
    public var hiddenPosts: [ATProtocolURI]

    /// Creates moderation settings.
    public init(
        adultContentEnabled: Bool = false,
        labels: [String: LabelPreference] = KnownLabels.defaultSettings,
        labelers: [ModerationPrefsLabeler] = [],
        mutedWords: [AppBskyActorDefs.MutedWord] = [],
        hiddenPosts: [ATProtocolURI] = []
    ) {
        self.adultContentEnabled = adultContentEnabled
        self.labels = labels
        self.labelers = labelers
        self.mutedWords = mutedWords
        self.hiddenPosts = hiddenPosts
    }
}

/// The label values every Bluesky client understands without consulting a labeler.
public enum KnownLabels {
    /// The default setting of each user-configurable built-in label.
    public static let defaultSettings: [String: LabelPreference] = [
        "porn": .hide,
        "sexual": .warn,
        "nudity": .ignore,
        "graphic-media": .warn,
    ]
}
