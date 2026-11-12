import Foundation

public extension BskyAgent {
    // MARK: Likes and reposts

    /// Likes a record (usually a post).
    ///
    /// - Parameters:
    ///   - subject: The record being liked.
    ///   - via: The repost through which the record was seen, if any.
    /// - Returns: The like record. Keep its URI to undo the like with ``deleteLike(_:)``.
    @discardableResult
    func like(
        _ subject: ComAtprotoRepoStrongRef,
        via: ComAtprotoRepoStrongRef? = nil
    ) async throws -> ComAtprotoRepoStrongRef {
        try await createRecord(
            AppBskyFeedLike(subject: subject, createdAt: Self.now(), via: via),
            collection: AppBskyFeedLike.typeIdentifier
        )
    }

    /// Removes a like.
    /// - Parameter likeURI: The URI of the like record, as returned by ``like(_:via:)``
    ///   or found in a post's `viewer.like`.
    func deleteLike(_ likeURI: ATProtocolURI) async throws {
        _ = try Self.recordLocation(likeURI, expecting: AppBskyFeedLike.typeIdentifier)
        try await deleteRecord(likeURI)
    }

    /// Reposts a post.
    ///
    /// - Parameters:
    ///   - subject: The post being reposted.
    ///   - via: The repost through which the post was seen, if any.
    /// - Returns: The repost record. Keep its URI to undo it with ``deleteRepost(_:)``.
    @discardableResult
    func repost(
        _ subject: ComAtprotoRepoStrongRef,
        via: ComAtprotoRepoStrongRef? = nil
    ) async throws -> ComAtprotoRepoStrongRef {
        try await createRecord(
            AppBskyFeedRepost(subject: subject, createdAt: Self.now(), via: via),
            collection: AppBskyFeedRepost.typeIdentifier
        )
    }

    /// Removes a repost.
    /// - Parameter repostURI: The URI of the repost record, as returned by
    ///   ``repost(_:via:)`` or found in a post's `viewer.repost`.
    func deleteRepost(_ repostURI: ATProtocolURI) async throws {
        _ = try Self.recordLocation(repostURI, expecting: AppBskyFeedRepost.typeIdentifier)
        try await deleteRecord(repostURI)
    }

    // MARK: Follows

    /// Follows an account.
    ///
    /// - Parameters:
    ///   - subject: The account to follow.
    ///   - via: The starter pack through which the account was found, if any.
    /// - Returns: The follow record. Keep its URI to unfollow with ``deleteFollow(_:)``.
    @discardableResult
    func follow(_ subject: DID, via: ComAtprotoRepoStrongRef? = nil) async throws -> ComAtprotoRepoStrongRef {
        try await createRecord(
            AppBskyGraphFollow(subject: subject, createdAt: Self.now(), via: via),
            collection: AppBskyGraphFollow.typeIdentifier
        )
    }

    /// Unfollows an account.
    /// - Parameter followURI: The URI of the follow record, as returned by
    ///   ``follow(_:via:)`` or found in a profile's `viewer.following`.
    func deleteFollow(_ followURI: ATProtocolURI) async throws {
        _ = try Self.recordLocation(followURI, expecting: AppBskyGraphFollow.typeIdentifier)
        try await deleteRecord(followURI)
    }

    // MARK: Blocks

    /// Blocks an account. Blocks are public records.
    /// - Returns: The block record. Keep its URI to unblock with ``deleteBlock(_:)``.
    @discardableResult
    func block(_ subject: DID) async throws -> ComAtprotoRepoStrongRef {
        try await createRecord(
            AppBskyGraphBlock(subject: subject, createdAt: Self.now()),
            collection: AppBskyGraphBlock.typeIdentifier
        )
    }

    /// Unblocks an account.
    /// - Parameter blockURI: The URI of the block record, as returned by
    ///   ``block(_:)`` or found in a profile's `viewer.blocking`.
    func deleteBlock(_ blockURI: ATProtocolURI) async throws {
        _ = try Self.recordLocation(blockURI, expecting: AppBskyGraphBlock.typeIdentifier)
        try await deleteRecord(blockURI)
    }

    /// Blocks every account on a moderation list.
    /// - Parameter list: The URI of the `app.bsky.graph.list` record.
    /// - Returns: The list-block record.
    @discardableResult
    func blockModList(_ list: ATProtocolURI) async throws -> ComAtprotoRepoStrongRef {
        _ = try Self.recordLocation(list, expecting: "app.bsky.graph.list")
        return try await createRecord(
            AppBskyGraphListblock(subject: list, createdAt: Self.now()),
            collection: AppBskyGraphListblock.typeIdentifier
        )
    }

    /// Stops blocking a moderation list.
    ///
    /// The list is read from the AppView to find the account's list-block
    /// record; nothing happens when the list is not blocked.
    ///
    /// - Parameter list: The URI of the `app.bsky.graph.list` record.
    /// - Returns: Whether a block was removed.
    @discardableResult
    func unblockModList(_ list: ATProtocolURI) async throws -> Bool {
        _ = try await did()
        let nsid = "app.bsky.graph.getList"
        let response = try await xrpcQuery(nsid, query: [
            URLQueryItem(name: "list", value: list.uriString()),
            URLQueryItem(name: "limit", value: "1"),
        ])
        guard let blocked = try response.json(nsid: nsid)["list"]?["viewer"]?["blocked"]?.stringValue else {
            return false
        }
        guard let blockURI = try? ATProtocolURI(uriString: blocked) else {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "viewer.blocked is not an at:// URI")
        }
        _ = try Self.recordLocation(blockURI, expecting: AppBskyGraphListblock.typeIdentifier)
        try await deleteRecord(blockURI)
        return true
    }

    // MARK: Mutes

    /// Mutes an account. Mutes are private and stored by the AppView.
    /// - Parameter actor: The account's DID or handle.
    func mute(_ actor: ATIdentifier) async throws {
        _ = try await xrpcProcedure("app.bsky.graph.muteActor", body: .object(["actor": .string(actor.stringValue())]))
    }

    /// Unmutes an account.
    /// - Parameter actor: The account's DID or handle.
    func unmute(_ actor: ATIdentifier) async throws {
        _ = try await xrpcProcedure("app.bsky.graph.unmuteActor", body: .object(["actor": .string(actor.stringValue())]))
    }

    /// Mutes every account on a moderation list.
    /// - Parameter list: The URI of the `app.bsky.graph.list` record.
    func muteModList(_ list: ATProtocolURI) async throws {
        _ = try await xrpcProcedure("app.bsky.graph.muteActorList", body: .object(["list": .string(list.uriString())]))
    }

    /// Stops muting a moderation list.
    /// - Parameter list: The URI of the `app.bsky.graph.list` record.
    func unmuteModList(_ list: ATProtocolURI) async throws {
        _ = try await xrpcProcedure("app.bsky.graph.unmuteActorList", body: .object(["list": .string(list.uriString())]))
    }

    /// Mutes a thread so its replies stop producing notifications.
    /// - Parameter root: The URI of the thread's root post.
    func muteThread(_ root: ATProtocolURI) async throws {
        _ = try await xrpcProcedure("app.bsky.graph.muteThread", body: .object(["root": .string(root.uriString())]))
    }

    /// Unmutes a thread.
    /// - Parameter root: The URI of the thread's root post.
    func unmuteThread(_ root: ATProtocolURI) async throws {
        _ = try await xrpcProcedure("app.bsky.graph.unmuteThread", body: .object(["root": .string(root.uriString())]))
    }

    // MARK: Notifications

    /// Marks notifications as seen up to a point in time.
    /// - Parameter seenAt: The cut-off; defaults to now.
    func updateSeenNotifications(seenAt: Date = Date()) async throws {
        let timestamp = try BskyJSON.encoding(["seenAt": ATProtocolDate(date: seenAt)])
        _ = try await xrpcProcedure("app.bsky.notification.updateSeen", body: timestamp)
    }

    // MARK: Profile

    /// Creates or updates the account's profile record with a read-modify-write.
    ///
    /// The current record is read, passed to `update`, and the returned record
    /// is written back on the condition that the stored record has not changed
    /// in the meantime. If another client wrote first, the whole cycle runs
    /// again with the fresh record, up to five more times.
    ///
    /// Fields of the stored record that this SDK's profile type does not model
    /// are carried over unchanged.
    ///
    /// ```swift
    /// try await client.bsky.upsertProfile { existing in
    ///     var profile = ProfileUpdate(existing)
    ///     profile.displayName = "Storm Petrel"
    ///     return profile.record
    /// }
    /// ```
    ///
    /// - Parameter update: Receives the stored profile (`nil` when there is
    ///   none, or when it is not a valid profile record) and returns the record to store.
    /// - Returns: The URI and CID of the stored profile.
    /// - Throws: ``BskyAgentError/swapRetriesExhausted(attempts:)`` when every
    ///   attempt lost the race; whatever `update` throws.
    @discardableResult
    func upsertProfile(
        _ update: @Sendable (AppBskyActorProfile?) async throws -> AppBskyActorProfile
    ) async throws -> ComAtprotoRepoStrongRef {
        let collection = AppBskyActorProfile.typeIdentifier
        return try await upsertRecordJSON(collection: collection, rkey: "self") { existing in
            let existingProfile = existing.flatMap { try? $0.value.decoded(as: AppBskyActorProfile.self) }

            let updated = try await update(existingProfile)
            var record = try Self.recordJSON(updated, collection: collection).json

            // Carry over what the typed model could not see.
            if let existing, let existingProfile, let stored = existing.value.objectValue,
               let modeled = try? BskyJSON.encoding(existingProfile).objectValue
            {
                for (key, value) in stored where modeled[key] == nil && record[key] == nil {
                    record[key] = value
                }
            }
            return record
        }
    }
}

/// A mutable copy of a profile record, for use inside ``BskyAgent/upsertProfile(_:)``.
///
/// The generated `AppBskyActorProfile` is immutable; this type lets an update
/// change a few fields and keep the rest.
public struct ProfileUpdate: Sendable {
    /// The display name, at most 64 graphemes.
    public var displayName: String?
    /// The free-form profile text, at most 256 graphemes.
    public var description: String?
    /// Free-form pronouns text.
    public var pronouns: String?
    /// A website link.
    public var website: URI?
    /// The uploaded avatar image.
    public var avatar: Blob?
    /// The uploaded banner image.
    public var banner: Blob?
    /// Self-label values applied to the account.
    public var labels: AppBskyActorProfile.AppBskyActorProfileLabelsUnion?
    /// The starter pack the account joined through.
    public var joinedViaStarterPack: ComAtprotoRepoStrongRef?
    /// The post pinned to the profile.
    public var pinnedPost: ComAtprotoRepoStrongRef?
    /// When the profile was first created.
    public var createdAt: ATProtocolDate?

    /// Starts from an existing profile record, or from an empty profile.
    public init(_ existing: AppBskyActorProfile? = nil) {
        displayName = existing?.displayName
        description = existing?.description
        pronouns = existing?.pronouns
        website = existing?.website
        avatar = existing?.avatar
        banner = existing?.banner
        labels = existing?.labels
        joinedViaStarterPack = existing?.joinedViaStarterPack
        pinnedPost = existing?.pinnedPost
        createdAt = existing?.createdAt
    }

    /// The profile record holding the current field values.
    public var record: AppBskyActorProfile {
        AppBskyActorProfile(
            displayName: displayName,
            description: description,
            pronouns: pronouns,
            website: website,
            avatar: avatar,
            banner: banner,
            labels: labels,
            joinedViaStarterPack: joinedViaStarterPack,
            pinnedPost: pinnedPost,
            createdAt: createdAt
        )
    }
}
