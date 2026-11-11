import Foundation

/// The Bluesky moderation decision engine.
///
/// Each `moderate…` function evaluates a view returned by the AppView against
/// the viewer's settings and returns a ``ModerationDecision``. The decision
/// then answers, per UI context, whether to filter, blur, alert or inform:
///
/// ```swift
/// let options = ModerationOptions(userDid: myDid, prefs: preferences.moderationPrefs)
/// let decision = Moderation.moderatePost(postView, options: options)
///
/// if decision.ui(.contentList).filter { return }        // drop from the feed
/// let media = decision.ui(.contentMedia)
/// if media.blur { showCover(canReveal: !media.noOverride) }
/// ```
///
/// The engine is a port of the moderation module of `@atproto/api` and makes
/// the same decisions for the same inputs. It only reads the labels present
/// on the views it is given: which labelers contribute labels is decided by
/// the `atproto-accept-labelers` header of the request that fetched them.
public enum Moderation {
    // MARK: Entry points

    /// Evaluates an account and its profile record.
    public static func moderateProfile(
        _ subject: some ModerationSubjectProfile,
        options: ModerationOptions
    ) -> ModerationDecision {
        .merge(
            decideAccount(subject, options: options),
            decideProfile(subject, options: options)
        )
    }

    /// Evaluates a post, the post it quotes (if any), and its author.
    ///
    /// Causes that come from a quoted post are marked ``ModerationCause/downgraded``.
    ///
    /// - Parameters:
    ///   - subject: The post view.
    ///   - options: The viewer's settings.
    ///   - now: The time used to decide whether a muted word has expired.
    public static func moderatePost(
        _ subject: AppBskyFeedDefs.PostView,
        options: ModerationOptions,
        now: Date = Date()
    ) -> ModerationDecision {
        .merge(
            decidePostSubject(subject, options: options, now: now),
            decideEmbed(subject.embed, options: options)?.downgraded(),
            decideAccount(subject.author, options: options),
            decideProfile(subject.author, options: options)
        )
    }

    /// Evaluates a notification and its author.
    public static func moderateNotification(
        _ subject: AppBskyNotificationListNotifications.Notification,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(
            did: subject.author.did,
            isMe: isViewer(subject.author.did, options)
        )
        for label in subject.labels ?? [] {
            decision.addLabel(.content, label, options: options)
        }
        return .merge(
            decision,
            decideAccount(subject.author, options: options),
            decideProfile(subject.author, options: options)
        )
    }

    /// Evaluates a feed generator and its creator.
    public static func moderateFeedGenerator(
        _ subject: AppBskyFeedDefs.GeneratorView,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(
            did: subject.creator.did,
            isMe: isViewer(subject.creator.did, options)
        )
        for label in subject.labels ?? [] {
            decision.addLabel(.content, label, options: options)
        }
        return .merge(
            decision,
            decideAccount(subject.creator, options: options),
            decideProfile(subject.creator, options: options)
        )
    }

    /// Evaluates a user list and, when the view includes it, its creator.
    ///
    /// For a view without a creator profile (`ListViewBasic`) the creator is
    /// taken from the authority of the list's AT URI.
    public static func moderateUserList(
        _ subject: some ModerationSubjectUserList,
        options: ModerationOptions
    ) -> ModerationDecision {
        if let creator = subject.moderationCreator {
            var decision = ModerationDecision(did: creator.did, isMe: isViewer(creator.did, options))
            for label in subject.labels ?? [] {
                decision.addLabel(.content, label, options: options)
            }
            return .merge(
                decision,
                decideAccount(creator, options: options),
                decideProfile(creator, options: options)
            )
        }

        let creatorDid = try? DID(didString: subject.uri.authority)
        var decision = ModerationDecision(
            did: creatorDid,
            isMe: creatorDid.map { isViewer($0, options) } ?? false
        )
        for label in subject.labels ?? [] {
            decision.addLabel(.content, label, options: options)
        }
        return decision
    }

    /// Evaluates an account's status (for example "live now") together with the account itself.
    public static func moderateStatus(
        _ subject: some ModerationSubjectProfile,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(did: subject.did, isMe: isViewer(subject.did, options))
        for label in subject.moderationStatus?.labels ?? [] {
            decision.addLabel(.content, label, options: options)
        }
        return .merge(
            decision,
            decideAccount(subject, options: options),
            decideProfile(subject, options: options)
        )
    }

    // MARK: Accounts and profiles

    static func isViewer(_ did: DID, _ options: ModerationOptions) -> Bool {
        did == options.userDid
    }

    /// Labels on an account's profile record carry the record's URI; every
    /// other label on a profile view is about the account as a whole.
    static func isProfileRecordLabel(_ label: ComAtprotoLabelDefs.Label) -> Bool {
        label.uri.uriString().hasSuffix("/app.bsky.actor.profile/self")
    }

    static func decideAccount(
        _ subject: some ModerationSubjectProfile,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(did: subject.did, isMe: isViewer(subject.did, options))
        addViewerState(subject.viewer, to: &decision)

        for label in subject.labels ?? []
            where !isProfileRecordLabel(label) || label.val == "!no-unauthenticated"
        {
            decision.addLabel(.account, label, options: options)
        }
        return decision
    }

    static func decideProfile(
        _ subject: some ModerationSubjectProfile,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(did: subject.did, isMe: isViewer(subject.did, options))
        for label in subject.labels ?? [] where isProfileRecordLabel(label) {
            decision.addLabel(.profile, label, options: options)
        }
        return decision
    }

    /// Adds mute and block causes from the viewer's relationship to an account.
    private static func addViewerState(
        _ viewer: AppBskyActorDefs.ViewerState?,
        to decision: inout ModerationDecision
    ) {
        guard let viewer else { return }
        if viewer.muted == true {
            if let list = viewer.mutedByList {
                decision.addMutedByList(list)
            } else {
                decision.addMuted(true)
            }
        }
        if viewer.blocking != nil {
            if let list = viewer.blockingByList {
                decision.addBlockingByList(list)
            } else {
                decision.addBlocking(true)
            }
        }
        decision.addBlockedBy(viewer.blockedBy == true)
    }

    // MARK: Posts

    private static func decidePostSubject(
        _ subject: AppBskyFeedDefs.PostView,
        options: ModerationOptions,
        now: Date
    ) -> ModerationDecision {
        var decision = ModerationDecision(
            did: subject.author.did,
            isMe: isViewer(subject.author.did, options)
        )
        for label in subject.labels ?? [] {
            decision.addLabel(.content, label, options: options)
        }
        decision.addHidden(isHidden(subject, hiddenPosts: options.prefs.hiddenPosts))
        if !decision.isMe {
            decision.addMutedWord(matchAllMuteWords(subject, mutedWords: options.prefs.mutedWords, now: now))
        }
        return decision
    }

    /// The quoted record of a post view's embed, whether quoted alone or alongside media.
    private static func quotedRecord(
        of embed: AppBskyFeedDefs.PostViewEmbedUnion?
    ) -> AppBskyEmbedRecord.ViewRecordUnion? {
        switch embed {
        case let .appBskyEmbedRecordView(view):
            return view.record
        case let .appBskyEmbedRecordWithMediaView(view):
            return view.record.record
        default:
            return nil
        }
    }

    private static func decideEmbed(
        _ embed: AppBskyFeedDefs.PostViewEmbedUnion?,
        options: ModerationOptions
    ) -> ModerationDecision? {
        switch quotedRecord(of: embed) {
        case let .appBskyEmbedRecordViewRecord(record):
            return decideQuotedPost(record, options: options)
        case let .appBskyEmbedRecordViewBlocked(blocked):
            return decideBlockedQuotedPost(blocked, options: options)
        default:
            return nil
        }
    }

    private static func decideQuotedPost(
        _ subject: AppBskyEmbedRecord.ViewRecord,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(
            did: subject.author.did,
            isMe: isViewer(subject.author.did, options)
        )
        for label in subject.labels ?? [] {
            decision.addLabel(.content, label, options: options)
        }
        return .merge(
            decision,
            decideAccount(subject.author, options: options),
            decideProfile(subject.author, options: options)
        )
    }

    private static func decideBlockedQuotedPost(
        _ subject: AppBskyEmbedRecord.ViewBlocked,
        options: ModerationOptions
    ) -> ModerationDecision {
        var decision = ModerationDecision(
            did: subject.author.did,
            isMe: isViewer(subject.author.did, options)
        )
        addViewerState(subject.author.viewer, to: &decision)
        return decision
    }

    private static func isHidden(_ subject: AppBskyFeedDefs.PostView, hiddenPosts: [ATProtocolURI]) -> Bool {
        if hiddenPosts.isEmpty {
            return false
        }
        let hidden = Set(hiddenPosts.map { $0.uriString() })
        if hidden.contains(subject.uri.uriString()) {
            return true
        }
        if case let .appBskyEmbedRecordViewRecord(record) = quotedRecord(of: subject.embed) {
            return hidden.contains(record.uri.uriString())
        }
        return false
    }

    // MARK: Muted words in posts

    /// The post record inside a record container, when it is one.
    private static func postRecord(_ container: ATProtocolValueContainer) -> AppBskyFeedPost? {
        if case let .knownType(value) = container {
            return value as? AppBskyFeedPost
        }
        return nil
    }

    private static func languageTags(_ post: AppBskyFeedPost?) -> [String] {
        post?.langs?.map(\.languageTag) ?? []
    }

    private static func linkCardText(title: String, description: String) -> String {
        title + " " + description
    }

    /// Tests the post text, its alt texts, its link card and the quoted post
    /// (text, alt texts, link card) and returns the first set of matches.
    private static func matchAllMuteWords(
        _ subject: AppBskyFeedDefs.PostView,
        mutedWords: [AppBskyActorDefs.MutedWord],
        now: Date
    ) -> [MuteWordMatch] {
        if mutedWords.isEmpty {
            return []
        }

        func match(
            _ text: String,
            facets: [AppBskyRichtextFacet]? = nil,
            tags: [String]? = nil,
            languages: [String],
            actor: AppBskyActorDefs.ProfileViewBasic
        ) -> [MuteWordMatch] {
            matchMuteWords(
                mutedWords: mutedWords,
                text: text,
                facets: facets,
                outlineTags: tags,
                languages: languages,
                actor: actor,
                now: now
            )
        }

        func firstMatch(inAltTexts alts: [String], languages: [String], actor: AppBskyActorDefs.ProfileViewBasic) -> [MuteWordMatch] {
            for alt in alts {
                let matches = match(alt, languages: languages, actor: actor)
                if !matches.isEmpty { return matches }
            }
            return []
        }

        let postAuthor = subject.author
        let post = postRecord(subject.record)

        if let post {
            let languages = languageTags(post)

            // post text
            let matches = match(post.text, facets: post.facets, tags: post.tags, languages: languages, actor: postAuthor)
            if !matches.isEmpty { return matches }

            switch post.embed {
            case let .appBskyEmbedImages(images):
                let matches = firstMatch(inAltTexts: images.images.map(\.alt), languages: languages, actor: postAuthor)
                if !matches.isEmpty { return matches }
            case let .appBskyEmbedGallery(gallery):
                let matches = firstMatch(inAltTexts: altTexts(gallery), languages: languages, actor: postAuthor)
                if !matches.isEmpty { return matches }
            default:
                break
            }
        }

        switch subject.embed {
        case let .appBskyEmbedRecordView(view):
            // quote post
            guard case let .appBskyEmbedRecordViewRecord(record) = view.record,
                  let embeddedPost = postRecord(record.value)
            else {
                return []
            }
            return matchQuotedPost(embeddedPost, author: record.author, match: match, firstMatch: firstMatch)

        case let .appBskyEmbedExternalView(view):
            // link card
            return match(
                linkCardText(title: view.external.title, description: view.external.description),
                languages: [],
                actor: postAuthor
            )

        case let .appBskyEmbedRecordWithMediaView(view):
            // quote post with media
            guard case let .appBskyEmbedRecordViewRecord(record) = view.record.record else {
                return []
            }
            let embedAuthor = record.author

            // quoted post text
            if let quoted = postRecord(record.value) {
                let matches = match(
                    quoted.text,
                    facets: quoted.facets,
                    tags: quoted.tags,
                    languages: languageTags(quoted),
                    actor: embedAuthor
                )
                if !matches.isEmpty { return matches }
            }

            // media attached next to the quote
            let languages = languageTags(post)
            switch view.media {
            case let .appBskyEmbedImagesView(images):
                return firstMatch(inAltTexts: images.images.map(\.alt), languages: languages, actor: embedAuthor)
            case let .appBskyEmbedGalleryView(gallery):
                return firstMatch(inAltTexts: altTexts(gallery), languages: languages, actor: embedAuthor)
            case let .appBskyEmbedExternalView(external):
                return match(
                    linkCardText(title: external.external.title, description: external.external.description),
                    languages: [],
                    actor: embedAuthor
                )
            default:
                return []
            }

        default:
            return []
        }
    }

    /// Tests a quoted post: its text, then whatever it embeds.
    private static func matchQuotedPost(
        _ embeddedPost: AppBskyFeedPost,
        author embedAuthor: AppBskyActorDefs.ProfileViewBasic,
        match: (String, [AppBskyRichtextFacet]?, [String]?, [String], AppBskyActorDefs.ProfileViewBasic) -> [MuteWordMatch],
        firstMatch: ([String], [String], AppBskyActorDefs.ProfileViewBasic) -> [MuteWordMatch]
    ) -> [MuteWordMatch] {
        let languages = languageTags(embeddedPost)

        // quoted post text
        let matches = match(embeddedPost.text, embeddedPost.facets, embeddedPost.tags, languages, embedAuthor)
        if !matches.isEmpty { return matches }

        switch embeddedPost.embed {
        case let .appBskyEmbedImages(images):
            // quoted post's images
            return firstMatch(images.images.map(\.alt), languages, embedAuthor)

        case let .appBskyEmbedGallery(gallery):
            // quoted post's gallery
            return firstMatch(altTexts(gallery), languages, embedAuthor)

        case let .appBskyEmbedExternal(external):
            // quoted post's link card
            return match(
                linkCardText(title: external.external.title, description: external.external.description),
                nil,
                nil,
                [],
                embedAuthor
            )

        case let .appBskyEmbedRecordWithMedia(recordWithMedia):
            // quoted post's media when it did a quote + media. The reference
            // implementation tests these without a language, so the
            // no-spaces-language exception never applies here.
            switch recordWithMedia.media {
            case let .appBskyEmbedExternal(external):
                return match(
                    linkCardText(title: external.external.title, description: external.external.description),
                    nil,
                    nil,
                    [],
                    embedAuthor
                )
            case let .appBskyEmbedImages(images):
                return firstMatch(images.images.map(\.alt), [], embedAuthor)
            case let .appBskyEmbedGallery(gallery):
                return firstMatch(altTexts(gallery), [], embedAuthor)
            default:
                return []
            }

        default:
            return []
        }
    }

    private static func altTexts(_ gallery: AppBskyEmbedGallery) -> [String] {
        gallery.items.compactMap { item in
            if case let .appBskyEmbedGalleryImage(image) = item { return image.alt }
            return nil
        }
    }

    private static func altTexts(_ gallery: AppBskyEmbedGallery.View) -> [String] {
        gallery.items.compactMap { item in
            if case let .appBskyEmbedGalleryViewImage(image) = item { return image.alt }
            return nil
        }
    }
}
