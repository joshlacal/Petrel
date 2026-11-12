import Foundation

/// What a moderation cause does to each part of the interface.
///
/// A behavior maps UI contexts (a profile in a list, a post's media, an
/// avatar, ...) to an action. A context with no action is left untouched.
public struct ModerationBehavior: Sendable, Hashable {
    /// What to do to a piece of UI.
    public enum Action: String, Sendable, Hashable, Codable, CaseIterable {
        /// Cover the content; the user may be able to reveal it.
        case blur
        /// Show a prominent warning next to the content.
        case alert
        /// Show a low-key notice next to the content.
        case inform
    }

    /// A place in the interface where moderation can apply.
    public enum Context: String, Sendable, Hashable, Codable, CaseIterable {
        /// A profile shown in a list of profiles (search results, followers).
        case profileList
        /// A profile shown on its own screen.
        case profileView
        /// An account's avatar, wherever it appears.
        case avatar
        /// An account's banner image.
        case banner
        /// An account's display name.
        case displayName
        /// A piece of content (post, feed, list) shown in a feed or listing.
        case contentList
        /// A piece of content opened on its own screen.
        case contentView
        /// The media (images, video, link card) attached to content.
        case contentMedia
    }

    /// Action for a profile shown in a list.
    public var profileList: Action?
    /// Action for a profile shown on its own screen.
    public var profileView: Action?
    /// Action for an avatar.
    public var avatar: Action?
    /// Action for a banner.
    public var banner: Action?
    /// Action for a display name.
    public var displayName: Action?
    /// Action for content shown in a listing.
    public var contentList: Action?
    /// Action for content opened on its own screen.
    public var contentView: Action?
    /// Action for media attached to content.
    public var contentMedia: Action?

    /// Creates a behavior. Contexts left `nil` are not affected.
    public init(
        profileList: Action? = nil,
        profileView: Action? = nil,
        avatar: Action? = nil,
        banner: Action? = nil,
        displayName: Action? = nil,
        contentList: Action? = nil,
        contentView: Action? = nil,
        contentMedia: Action? = nil
    ) {
        self.profileList = profileList
        self.profileView = profileView
        self.avatar = avatar
        self.banner = banner
        self.displayName = displayName
        self.contentList = contentList
        self.contentView = contentView
        self.contentMedia = contentMedia
    }

    /// The action for `context`, or `nil` when the context is unaffected.
    public subscript(context: Context) -> Action? {
        get {
            switch context {
            case .profileList: return profileList
            case .profileView: return profileView
            case .avatar: return avatar
            case .banner: return banner
            case .displayName: return displayName
            case .contentList: return contentList
            case .contentView: return contentView
            case .contentMedia: return contentMedia
            }
        }
        set {
            switch context {
            case .profileList: profileList = newValue
            case .profileView: profileView = newValue
            case .avatar: avatar = newValue
            case .banner: banner = newValue
            case .displayName: displayName = newValue
            case .contentList: contentList = newValue
            case .contentView: contentView = newValue
            case .contentMedia: contentMedia = newValue
            }
        }
    }

    /// How a block (in either direction) is presented.
    public static let block = ModerationBehavior(
        profileList: .blur,
        profileView: .alert,
        avatar: .blur,
        banner: .blur,
        contentList: .blur,
        contentView: .blur
    )

    /// How a muted account is presented.
    public static let mute = ModerationBehavior(
        profileList: .inform,
        profileView: .alert,
        contentList: .blur,
        contentView: .inform
    )

    /// How content matching a muted word is presented.
    public static let muteWord = ModerationBehavior(
        contentList: .blur,
        contentView: .blur
    )

    /// How a post the user hid is presented.
    public static let hide = ModerationBehavior(
        contentList: .blur,
        contentView: .blur
    )

    /// A behavior that does nothing.
    public static let noop = ModerationBehavior()
}

/// What a label is attached to, which decides which behavior of its definition applies.
public enum LabelTarget: String, Sendable, Hashable, Codable, CaseIterable {
    /// The label is on the account as a whole (its URI is the account DID).
    case account
    /// The label is on the account's profile record.
    case profile
    /// The label is on a piece of content: a post, feed generator, list or status.
    case content
}

/// A property of a label definition that changes how it is enforced.
public enum LabelValueDefinitionFlag: String, Sendable, Hashable, Codable, CaseIterable {
    /// The user cannot click through a blur caused by this label.
    case noOverride = "no-override"
    /// The label marks adult content; it is forced to "hide" unless the user enabled adult content.
    case adult
    /// The label only applies to signed-out viewers.
    case unauthed
    /// The label is ignored when an account applies it to itself.
    case noSelf = "no-self"
}
