import Foundation

/// A label value definition expanded into the concrete behaviors a client applies.
///
/// Built-in definitions come from ``KnownLabels/definitions``. A labeler's own
/// definitions (`labelValueDefinitions` in its `app.bsky.labeler.service`
/// record) are expanded with
/// ``Moderation/interpretLabelValueDefinition(_:definedBy:)``.
public struct InterpretedLabelValueDefinition: Sendable, Hashable {
    /// The behaviors of a definition for each kind of label target.
    public struct Behaviors: Sendable, Hashable {
        /// Applied when the label is on an account.
        public var account: ModerationBehavior
        /// Applied when the label is on a profile record.
        public var profile: ModerationBehavior
        /// Applied when the label is on a piece of content.
        public var content: ModerationBehavior

        /// Creates a behavior set. Targets default to doing nothing.
        public init(
            account: ModerationBehavior = .noop,
            profile: ModerationBehavior = .noop,
            content: ModerationBehavior = .noop
        ) {
            self.account = account
            self.profile = profile
            self.content = content
        }

        /// The behavior for a label attached to `target`.
        public subscript(target: LabelTarget) -> ModerationBehavior {
            switch target {
            case .account: return account
            case .profile: return profile
            case .content: return content
            }
        }
    }

    /// The label value this definition describes (the label's `val`).
    public var identifier: String
    /// How strongly the label is surfaced: `alert`, `inform` or `none`.
    public var severity: String
    /// What the label hides: `content`, `media` or `none`.
    public var blurs: String
    /// The setting used when the user has not chosen one.
    public var defaultSetting: LabelPreference
    /// Whether the label can only be shown to users who enabled adult content.
    public var adultOnly: Bool
    /// Human-readable names and descriptions supplied by the labeler.
    public var locales: [ComAtprotoLabelDefs.LabelValueDefinitionStrings]
    /// The labeler that defined this value, or `nil` for a built-in definition.
    public var definedBy: DID?
    /// Whether the user may change the setting. Imperative labels such as `!hide` are not configurable.
    public var configurable: Bool
    /// Properties that change how the label is enforced.
    public var flags: [LabelValueDefinitionFlag]
    /// What the label does, per target.
    public var behaviors: Behaviors

    /// Creates a definition.
    public init(
        identifier: String,
        severity: String,
        blurs: String,
        defaultSetting: LabelPreference,
        adultOnly: Bool = false,
        locales: [ComAtprotoLabelDefs.LabelValueDefinitionStrings] = [],
        definedBy: DID? = nil,
        configurable: Bool,
        flags: [LabelValueDefinitionFlag],
        behaviors: Behaviors
    ) {
        self.identifier = identifier
        self.severity = severity
        self.blurs = blurs
        self.defaultSetting = defaultSetting
        self.adultOnly = adultOnly
        self.locales = locales
        self.definedBy = definedBy
        self.configurable = configurable
        self.flags = flags
        self.behaviors = behaviors
    }
}

public extension KnownLabels {
    /// The built-in label definitions, keyed by label value.
    ///
    /// This is the table the official client ships (`definitions/labels.json`
    /// in `@atproto/api`), with deprecated aliases expanded into entries of
    /// their own: `gore` behaves exactly like `graphic-media`.
    static let definitions: [String: InterpretedLabelValueDefinition] = {
        let blurEverything = ModerationBehavior(
            profileList: .blur,
            profileView: .blur,
            avatar: .blur,
            banner: .blur,
            displayName: .blur,
            contentList: .blur,
            contentView: .blur
        )
        let blurProfileIdentity = ModerationBehavior(avatar: .blur, banner: .blur, displayName: .blur)
        let blurContent = ModerationBehavior(contentList: .blur, contentView: .blur)
        let blurProfileMedia = ModerationBehavior(avatar: .blur, banner: .blur)
        let mediaBehaviors = InterpretedLabelValueDefinition.Behaviors(
            account: blurProfileMedia,
            profile: blurProfileMedia,
            content: ModerationBehavior(contentMedia: .blur)
        )

        func media(
            _ identifier: String,
            _ defaultSetting: LabelPreference,
            flags: [LabelValueDefinitionFlag]
        ) -> InterpretedLabelValueDefinition {
            InterpretedLabelValueDefinition(
                identifier: identifier,
                severity: "none",
                blurs: "media",
                defaultSetting: defaultSetting,
                configurable: true,
                flags: flags,
                behaviors: mediaBehaviors
            )
        }

        let all: [InterpretedLabelValueDefinition] = [
            InterpretedLabelValueDefinition(
                identifier: "!hide",
                severity: "alert",
                blurs: "content",
                defaultSetting: .hide,
                configurable: false,
                flags: [.noOverride, .noSelf],
                behaviors: .init(account: blurEverything, profile: blurProfileIdentity, content: blurContent)
            ),
            InterpretedLabelValueDefinition(
                identifier: "!warn",
                severity: "none",
                blurs: "content",
                defaultSetting: .warn,
                configurable: false,
                flags: [.noSelf],
                behaviors: .init(
                    account: ModerationBehavior(
                        profileList: .blur,
                        profileView: .blur,
                        avatar: .blur,
                        banner: .blur,
                        contentList: .blur,
                        contentView: .blur
                    ),
                    profile: blurProfileIdentity,
                    content: blurContent
                )
            ),
            InterpretedLabelValueDefinition(
                identifier: "!no-unauthenticated",
                severity: "none",
                blurs: "content",
                defaultSetting: .hide,
                configurable: false,
                flags: [.noOverride, .unauthed],
                behaviors: .init(account: blurEverything, profile: blurProfileIdentity, content: blurContent)
            ),
            media("porn", .hide, flags: [.adult]),
            media("sexual", .warn, flags: [.adult]),
            media("nudity", .ignore, flags: []),
            media("graphic-media", .warn, flags: [.adult]),
            // Deprecated alias of `graphic-media`.
            media("gore", .warn, flags: [.adult]),
        ]
        return Dictionary(all.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
    }()
}

public extension Moderation {
    /// Expands a labeler's label value definition into client behaviors.
    ///
    /// `blurs` selects what is covered (`content`, `media` or `none`),
    /// `severity` whether an alert or an informational notice accompanies it,
    /// and `adultOnly` forces a blur on the content screen and marks the label
    /// as adult. Custom definitions are always user-configurable and never
    /// apply to self-labels.
    ///
    /// - Parameters:
    ///   - definition: The definition from the labeler's service record.
    ///   - definedBy: The labeler's DID, or `nil` for a global definition.
    static func interpretLabelValueDefinition(
        _ definition: ComAtprotoLabelDefs.LabelValueDefinition,
        definedBy: DID?
    ) -> InterpretedLabelValueDefinition {
        var behaviors = InterpretedLabelValueDefinition.Behaviors()
        let adultOnly = definition.adultOnly ?? false
        let alertOrInform: ModerationBehavior.Action?
        switch definition.severity {
        case "alert": alertOrInform = .alert
        case "inform": alertOrInform = .inform
        default: alertOrInform = nil
        }

        switch definition.blurs {
        case "content":
            behaviors.account.profileList = alertOrInform
            behaviors.account.profileView = alertOrInform
            behaviors.account.contentList = .blur
            behaviors.account.contentView = adultOnly ? .blur : alertOrInform
            behaviors.profile.profileList = alertOrInform
            behaviors.profile.profileView = alertOrInform
            behaviors.content.contentList = .blur
            behaviors.content.contentView = adultOnly ? .blur : alertOrInform
        case "media":
            behaviors.account.profileList = alertOrInform
            behaviors.account.profileView = alertOrInform
            behaviors.account.avatar = .blur
            behaviors.account.banner = .blur
            behaviors.profile.profileList = alertOrInform
            behaviors.profile.profileView = alertOrInform
            behaviors.profile.avatar = .blur
            behaviors.profile.banner = .blur
            behaviors.content.contentMedia = .blur
        case "none":
            behaviors.account.profileList = alertOrInform
            behaviors.account.profileView = alertOrInform
            behaviors.account.contentList = alertOrInform
            behaviors.account.contentView = alertOrInform
            behaviors.profile.profileList = alertOrInform
            behaviors.profile.profileView = alertOrInform
            behaviors.content.contentList = alertOrInform
            behaviors.content.contentView = alertOrInform
        default:
            break
        }

        let defaultSetting: LabelPreference
        switch definition.defaultSetting {
        case "hide": defaultSetting = .hide
        case "ignore": defaultSetting = .ignore
        default: defaultSetting = .warn
        }

        var flags: [LabelValueDefinitionFlag] = [.noSelf]
        if adultOnly {
            flags.append(.adult)
        }

        return InterpretedLabelValueDefinition(
            identifier: definition.identifier,
            severity: definition.severity,
            blurs: definition.blurs,
            defaultSetting: defaultSetting,
            adultOnly: adultOnly,
            locales: definition.locales,
            definedBy: definedBy,
            configurable: true,
            flags: flags,
            behaviors: behaviors
        )
    }

    /// Expands every label value definition a labeler publishes.
    ///
    /// The result is the value for the labeler's DID in ``ModerationOptions/labelDefs``.
    static func interpretLabelValueDefinitions(
        _ labelerView: AppBskyLabelerDefs.LabelerViewDetailed
    ) -> [InterpretedLabelValueDefinition] {
        (labelerView.policies.labelValueDefinitions ?? []).map {
            interpretLabelValueDefinition($0, definedBy: labelerView.creator.did)
        }
    }
}
