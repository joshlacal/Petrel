import Foundation

/// What a post embeds: media (images, a video or a link card), a quoted
/// record, or both.
///
/// ```swift
/// let blob = try await client.bsky.uploadImage(jpegData, mimeType: "image/jpeg")
/// let embed = try PostEmbed.images([
///     .init(image: blob, alt: "A petrel over the sea", width: 1600, height: 900),
/// ])
/// try await client.bsky.post("Seen today", embed: embed)
/// try await client.bsky.post("Agreed", embed: .quote(otherPost))
/// ```
public struct PostEmbed: Sendable, Hashable {
    /// The media part of an embed.
    public enum Media: Sendable, Hashable {
        /// One to four images.
        case images([AppBskyEmbedImages.Image])
        /// One video.
        case video(AppBskyEmbedVideo)
        /// A link card.
        case external(AppBskyEmbedExternal.External)
    }

    /// The most images one post can carry (`app.bsky.embed.images`).
    public static let maxImages = 4

    private enum Content: Sendable, Hashable {
        case media(Media)
        case quote(ComAtprotoRepoStrongRef)
        case quoteWithMedia(ComAtprotoRepoStrongRef, Media)
    }

    private let content: Content

    /// The media of the embed, if any.
    public var media: Media? {
        switch content {
        case let .media(media), let .quoteWithMedia(_, media): return media
        case .quote: return nil
        }
    }

    /// The quoted record, if any.
    public var quote: ComAtprotoRepoStrongRef? {
        switch content {
        case let .quote(record), let .quoteWithMedia(record, _): return record
        case .media: return nil
        }
    }

    /// Embeds one to four images that were already uploaded.
    ///
    /// Upload them with ``BskyAgent/uploadImage(_:mimeType:stripMetadata:)``,
    /// which removes their metadata, or let
    /// ``BskyAgent/post(_:images:stripImageMetadata:quote:reply:langs:labels:tags:createdAt:)``
    /// upload and embed in one step. ``BskyAgent/uploadBlob(_:mimeType:)``
    /// uploads bytes as they are, metadata included.
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` for zero or more than four images.
    public static func images(_ images: [AppBskyEmbedImages.Image]) throws -> PostEmbed {
        guard !images.isEmpty, images.count <= maxImages else {
            throw BskyAgentError.invalidInput("A post embeds between 1 and \(maxImages) images, got \(images.count)")
        }
        return PostEmbed(content: .media(.images(images)))
    }

    /// Embeds a link card.
    /// - Parameters:
    ///   - uri: The page the card links to.
    ///   - title: The card title.
    ///   - description: The card description.
    ///   - thumb: An uploaded thumbnail image, if any.
    public static func external(uri: URI, title: String, description: String, thumb: Blob? = nil) -> PostEmbed {
        PostEmbed(content: .media(.external(
            AppBskyEmbedExternal.External(uri: uri, title: title, description: description, thumb: thumb)
        )))
    }

    /// Embeds an uploaded video.
    /// - Parameters:
    ///   - video: The video blob.
    ///   - alt: Alt text describing the video.
    ///   - aspectRatio: The video's width and height.
    ///   - captions: Caption tracks.
    public static func video(
        _ video: Blob,
        alt: String? = nil,
        aspectRatio: AppBskyEmbedDefs.AspectRatio? = nil,
        captions: [AppBskyEmbedVideo.Caption]? = nil
    ) -> PostEmbed {
        PostEmbed(content: .media(.video(
            AppBskyEmbedVideo(video: video, captions: captions, alt: alt, aspectRatio: aspectRatio)
        )))
    }

    /// Quotes a record: a post, or a feed generator, list, labeler or starter pack.
    public static func quote(_ record: ComAtprotoRepoStrongRef) -> PostEmbed {
        PostEmbed(content: .quote(record))
    }

    /// Returns this embed with a quoted record added, keeping its media.
    public func quoting(_ record: ComAtprotoRepoStrongRef) -> PostEmbed {
        PostEmbed(content: media.map { .quoteWithMedia(record, $0) } ?? .quote(record))
    }

    /// The embed as the `embed` field of an `app.bsky.feed.post` record.
    public var recordEmbed: AppBskyFeedPost.AppBskyFeedPostEmbedUnion {
        switch content {
        case let .quote(record):
            return .appBskyEmbedRecord(AppBskyEmbedRecord(record: record))
        case let .media(.images(images)):
            return .appBskyEmbedImages(AppBskyEmbedImages(images: images))
        case let .media(.video(video)):
            return .appBskyEmbedVideo(video)
        case let .media(.external(external)):
            return .appBskyEmbedExternal(AppBskyEmbedExternal(external: external))
        case let .quoteWithMedia(record, media):
            let mediaUnion: AppBskyEmbedRecordWithMedia.AppBskyEmbedRecordWithMediaMediaUnion
            switch media {
            case let .images(images): mediaUnion = .appBskyEmbedImages(AppBskyEmbedImages(images: images))
            case let .video(video): mediaUnion = .appBskyEmbedVideo(video)
            case let .external(external): mediaUnion = .appBskyEmbedExternal(AppBskyEmbedExternal(external: external))
            }
            return .appBskyEmbedRecordWithMedia(AppBskyEmbedRecordWithMedia(
                record: AppBskyEmbedRecord(record: record),
                media: mediaUnion
            ))
        }
    }
}

/// An image file to attach to a post with ``BskyAgent/post(_:images:stripImageMetadata:quote:reply:langs:labels:tags:createdAt:)``.
public struct PostImage: Sendable, Hashable {
    /// The file contents.
    public var data: Data
    /// The media type of the file, for example `image/jpeg`.
    public var mimeType: String
    /// Alt text describing the image for people who cannot see it.
    public var alt: String
    /// The pixel dimensions, so clients can lay the image out before it loads.
    public var aspectRatio: AppBskyEmbedDefs.AspectRatio?

    /// Creates an image attachment.
    public init(data: Data, mimeType: String, alt: String, aspectRatio: AppBskyEmbedDefs.AspectRatio? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.alt = alt
        self.aspectRatio = aspectRatio
    }

    /// Creates an image attachment with its pixel dimensions.
    public init(data: Data, mimeType: String, alt: String, width: Int, height: Int) {
        self.init(
            data: data,
            mimeType: mimeType,
            alt: alt,
            aspectRatio: AppBskyEmbedDefs.AspectRatio(width: width, height: height)
        )
    }
}

public extension AppBskyEmbedImages.Image {
    /// Creates an image with its pixel dimensions.
    ///
    /// Supplying the dimensions lets clients lay the image out before it loads.
    init(image: Blob, alt: String, width: Int, height: Int) {
        self.init(image: image, alt: alt, aspectRatio: AppBskyEmbedDefs.AspectRatio(width: width, height: height))
    }
}

public extension ComAtprotoRepoStrongRef {
    /// A strong reference to a post as returned by the AppView.
    init(_ post: AppBskyFeedDefs.PostView) {
        self.init(uri: post.uri, cid: post.cid)
    }
}

public extension BskyAgent {
    // MARK: Posting

    /// Publishes a post, detecting links, mentions and tags in the text.
    ///
    /// Mentioned handles are resolved to DIDs through the PDS; a handle that
    /// does not resolve stays plain text. To supply facets yourself, pass a
    /// ``RichText`` to the overload of this method that takes one.
    ///
    /// - Parameters:
    ///   - text: The post text, at most 300 graphemes.
    ///   - reply: The thread position when this post is a reply; build it with `replyRef(to:)`.
    ///   - embed: Images, a video, a link card and/or a quoted record.
    ///   - langs: BCP 47 language tags of the text, at most three.
    ///   - labels: Self-label values, for example `"porn"` or `"graphic-media"`.
    ///   - tags: Additional hashtags that are not part of the text.
    ///   - createdAt: The post's timestamp; defaults to now.
    /// - Returns: The URI and CID of the new post.
    @discardableResult
    func post(
        _ text: String,
        reply: AppBskyFeedPost.ReplyRef? = nil,
        embed: PostEmbed? = nil,
        langs: [String]? = nil,
        labels: [String]? = nil,
        tags: [String]? = nil,
        createdAt: Date = Date()
    ) async throws -> ComAtprotoRepoStrongRef {
        var richText = RichText(text: text)
        await richText.detectFacets { handle in
            try await self.resolveHandle(handle)
        }
        return try await post(
            richText,
            reply: reply,
            embed: embed,
            langs: langs,
            labels: labels,
            tags: tags,
            createdAt: createdAt
        )
    }

    /// Publishes a post with exactly the given text and facets.
    ///
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when the text exceeds 300
    ///   graphemes or 3000 bytes, or more than three languages are given.
    @discardableResult
    func post(
        _ richText: RichText,
        reply: AppBskyFeedPost.ReplyRef? = nil,
        embed: PostEmbed? = nil,
        langs: [String]? = nil,
        labels: [String]? = nil,
        tags: [String]? = nil,
        createdAt: Date = Date()
    ) async throws -> ComAtprotoRepoStrongRef {
        guard !richText.exceedsPostLimits else {
            throw BskyAgentError.invalidInput(
                "Post text is \(richText.graphemeLength) graphemes / \(richText.utf8Length) bytes; "
                    + "the limit is \(RichText.maxPostGraphemes) graphemes / \(RichText.maxPostUTF8Bytes) bytes"
            )
        }
        if let langs, langs.count > 3 {
            throw BskyAgentError.invalidInput("A post declares at most 3 languages, got \(langs.count)")
        }
        let record = AppBskyFeedPost(
            text: richText.text,
            facets: richText.recordFacets,
            reply: reply,
            embed: embed?.recordEmbed,
            langs: langs?.map { LanguageCodeContainer(languageCode: $0) },
            labels: labels.flatMap { values in
                values.isEmpty ? nil : .comAtprotoLabelDefsSelfLabels(
                    ComAtprotoLabelDefs.SelfLabels(values: values.map { ComAtprotoLabelDefs.SelfLabel(val: $0) })
                )
            },
            tags: tags,
            createdAt: ATProtocolDate(date: createdAt)
        )
        return try await post(record: record)
    }

    /// Publishes a fully formed post record.
    @discardableResult
    func post(record: AppBskyFeedPost) async throws -> ComAtprotoRepoStrongRef {
        try await createRecord(record, collection: AppBskyFeedPost.typeIdentifier)
    }

    /// Deletes one of the account's posts.
    func deletePost(_ uri: ATProtocolURI) async throws {
        _ = try Self.recordLocation(uri, expecting: AppBskyFeedPost.typeIdentifier)
        try await deleteRecord(uri)
    }

    // MARK: Replies and quotes

    /// Builds the reply reference for answering a post, reading the parent
    /// record to find the thread root.
    ///
    /// A reply names both its parent and the root of the thread. When the
    /// parent is itself a reply its root is carried over; otherwise the parent
    /// is the root.
    ///
    /// - Parameter parent: The post being answered.
    func replyRef(to parent: ComAtprotoRepoStrongRef) async throws -> AppBskyFeedPost.ReplyRef {
        let location = try Self.recordLocation(parent.uri, expecting: AppBskyFeedPost.typeIdentifier)
        guard let raw = try await getRecordJSON(
            repo: location.repo,
            collection: AppBskyFeedPost.typeIdentifier,
            rkey: location.rkey
        ) else {
            throw BskyAgentError.invalidInput("The post being replied to does not exist: \(parent.uri.uriString())")
        }
        if let root = raw.value["reply"]?["root"],
           let rootRef = try? root.decoded(as: ComAtprotoRepoStrongRef.self)
        {
            return AppBskyFeedPost.ReplyRef(root: rootRef, parent: parent)
        }
        return AppBskyFeedPost.ReplyRef(root: parent, parent: parent)
    }

    /// Builds the reply reference for answering a post the AppView returned,
    /// without a network call.
    func replyRef(to parent: AppBskyFeedDefs.PostView) -> AppBskyFeedPost.ReplyRef {
        let parentRef = ComAtprotoRepoStrongRef(parent)
        if case let .knownType(value) = parent.record,
           let record = value as? AppBskyFeedPost,
           let root = record.reply?.root
        {
            return AppBskyFeedPost.ReplyRef(root: root, parent: parentRef)
        }
        return AppBskyFeedPost.ReplyRef(root: parentRef, parent: parentRef)
    }

    /// Replies to a post, detecting facets in the text.
    ///
    /// The parent record is read once to find the thread root. When you
    /// already hold the parent as a `PostView`, build the reference with
    /// `replyRef(to:)` and call `post(_:reply:)` to avoid that read.
    @discardableResult
    func reply(
        to parent: ComAtprotoRepoStrongRef,
        _ text: String,
        embed: PostEmbed? = nil,
        langs: [String]? = nil,
        labels: [String]? = nil
    ) async throws -> ComAtprotoRepoStrongRef {
        let reference = try await replyRef(to: parent)
        return try await post(text, reply: reference, embed: embed, langs: langs, labels: labels)
    }

    /// Quote-posts a record, detecting facets in the text.
    @discardableResult
    func quote(
        _ record: ComAtprotoRepoStrongRef,
        _ text: String,
        media: PostEmbed? = nil,
        langs: [String]? = nil,
        labels: [String]? = nil
    ) async throws -> ComAtprotoRepoStrongRef {
        try await post(text, embed: media?.quoting(record) ?? .quote(record), langs: langs, labels: labels)
    }

    // MARK: Interaction gates

    /// Restricts who may reply to one of the account's posts
    /// (`app.bsky.feed.threadgate`).
    ///
    /// - Parameters:
    ///   - post: The post to gate. It must belong to the signed-in account.
    ///   - allow: Who may reply. An empty array means nobody; `nil` means everyone.
    ///
    /// An existing threadgate is updated in place: its hidden replies, its
    /// creation time and any fields this SDK does not model are kept.
    ///
    /// - Throws: ``BskyAgentError/swapRetriesExhausted(attempts:)`` when the
    ///   gate kept changing underneath the update.
    @discardableResult
    func setThreadgate(
        for post: ATProtocolURI,
        allow: [AppBskyFeedThreadgate.AppBskyFeedThreadgateAllowUnion]?
    ) async throws -> ComAtprotoRepoStrongRef {
        let location = try Self.recordLocation(post, expecting: AppBskyFeedPost.typeIdentifier)
        let record = AppBskyFeedThreadgate(post: post, allow: allow, createdAt: Self.now())
        return try await updateGate(record, collection: AppBskyFeedThreadgate.typeIdentifier, rkey: location.rkey, ruleKey: "allow")
    }

    /// Restricts how one of the account's posts may be embedded
    /// (`app.bsky.feed.postgate`).
    ///
    /// - Parameters:
    ///   - post: The post to gate. It must belong to the signed-in account.
    ///   - embeddingRules: For example `[.appBskyFeedPostgateDisableRule(.init())]` to disable quote posts.
    ///
    /// An existing postgate is updated in place: its detached quote posts, its
    /// creation time and any fields this SDK does not model are kept.
    ///
    /// - Throws: ``BskyAgentError/swapRetriesExhausted(attempts:)`` when the
    ///   gate kept changing underneath the update.
    @discardableResult
    func setPostgate(
        for post: ATProtocolURI,
        embeddingRules: [AppBskyFeedPostgate.AppBskyFeedPostgateEmbeddingRulesUnion]?
    ) async throws -> ComAtprotoRepoStrongRef {
        let location = try Self.recordLocation(post, expecting: AppBskyFeedPost.typeIdentifier)
        let record = AppBskyFeedPostgate(createdAt: Self.now(), post: post, embeddingRules: embeddingRules)
        return try await updateGate(record, collection: AppBskyFeedPostgate.typeIdentifier, rkey: location.rkey, ruleKey: "embeddingRules")
    }

    /// Writes a gate's rules over the stored gate, keeping everything else it holds.
    ///
    /// Only `ruleKey`, `post` and `$type` come from `gate`; `createdAt` is kept
    /// when the stored gate has one. Moderation state such as hidden replies or
    /// detached quotes is carried over, never reset.
    private func updateGate<Gate: Encodable>(
        _ gate: Gate,
        collection: String,
        rkey: String,
        ruleKey: String
    ) async throws -> ComAtprotoRepoStrongRef {
        let fresh = try Self.recordJSON(gate, collection: collection).json
        guard let freshFields = fresh.objectValue else {
            throw BskyAgentError.invalidInput("A record must encode to a JSON object")
        }
        return try await upsertRecordJSON(collection: collection, rkey: rkey) { existing in
            guard var record = existing?.value.objectValue else { return fresh }
            for key in ["$type", "post", ruleKey] {
                record[key] = freshFields[key]
            }
            if record["createdAt"] == nil {
                record["createdAt"] = freshFields["createdAt"]
            }
            return .object(record)
        }
    }

    // MARK: Images

    /// Uploads an image, removing its metadata first.
    ///
    /// By default the image is passed through
    /// ``ImageMetadataStripper/stripMetadata(from:mimeType:)`` before it leaves
    /// the device: location (GPS), capture time, device details, embedded
    /// thumbnails and similar metadata are removed, while the pixels, colour
    /// profile and orientation are kept and the format is unchanged. If the
    /// metadata cannot be removed, the upload does not happen.
    ///
    /// - Parameters:
    ///   - data: The image file.
    ///   - mimeType: The media type, for example `image/jpeg`. Must be `image/*`.
    ///   - stripMetadata: Pass `false` to upload the file with its metadata intact.
    /// - Returns: The uploaded blob, for use in an embed or a profile.
    /// - Throws: ``ImageMetadataStrippingError`` when stripping is requested
    ///   and not possible; ``BskyAgentError/invalidInput(_:)`` when `mimeType`
    ///   is not an image type.
    func uploadImage(_ data: Data, mimeType: String, stripMetadata: Bool = true) async throws -> Blob {
        try await uploadBlob(Self.preparedImage(data, mimeType: mimeType, stripMetadata: stripMetadata), mimeType: mimeType)
    }

    /// Publishes a post with images, uploading them first.
    ///
    /// Image metadata is removed before upload unless `stripImageMetadata` is
    /// `false`; see ``uploadImage(_:mimeType:stripMetadata:)``. All images are
    /// checked and stripped before the first one is uploaded, so a problem
    /// with any of them leaves nothing behind. Links, mentions and hashtags in
    /// the text are detected as in the text-only `post`.
    ///
    /// ```swift
    /// try await client.bsky.post("Seen today", images: [
    ///     PostImage(data: jpegData, mimeType: "image/jpeg", alt: "A storm petrel", width: 1600, height: 900),
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - text: The post text.
    ///   - images: One to four images.
    ///   - stripImageMetadata: Pass `false` to upload the files with their metadata intact.
    ///   - quote: A record to quote alongside the images.
    ///   - reply: The thread position when this post is a reply.
    ///   - langs: BCP 47 language tags of the text, at most three.
    ///   - labels: Self-label values, for example `"porn"` or `"graphic-media"`.
    ///   - tags: Additional hashtags that are not part of the text.
    ///   - createdAt: The post's timestamp; defaults to now.
    /// - Returns: The URI and CID of the new post.
    @discardableResult
    func post(
        _ text: String,
        images: [PostImage],
        stripImageMetadata: Bool = true,
        quote: ComAtprotoRepoStrongRef? = nil,
        reply: AppBskyFeedPost.ReplyRef? = nil,
        langs: [String]? = nil,
        labels: [String]? = nil,
        tags: [String]? = nil,
        createdAt: Date = Date()
    ) async throws -> ComAtprotoRepoStrongRef {
        guard !images.isEmpty, images.count <= PostEmbed.maxImages else {
            throw BskyAgentError.invalidInput(
                "A post embeds between 1 and \(PostEmbed.maxImages) images, got \(images.count)"
            )
        }
        _ = try await did() // fail before doing any work when signed out
        let prepared = try images.map {
            try Self.preparedImage($0.data, mimeType: $0.mimeType, stripMetadata: stripImageMetadata)
        }
        var uploaded: [AppBskyEmbedImages.Image] = []
        for (image, data) in zip(images, prepared) {
            let blob = try await uploadBlob(data, mimeType: image.mimeType)
            uploaded.append(AppBskyEmbedImages.Image(image: blob, alt: image.alt, aspectRatio: image.aspectRatio))
        }
        let embed = try PostEmbed.images(uploaded)
        return try await post(
            text,
            reply: reply,
            embed: quote.map(embed.quoting) ?? embed,
            langs: langs,
            labels: labels,
            tags: tags,
            createdAt: createdAt
        )
    }

    /// Sets the profile picture, uploading it first.
    ///
    /// Image metadata is removed before upload unless `stripMetadata` is
    /// `false`; see ``uploadImage(_:mimeType:stripMetadata:)``. The rest of
    /// the profile is left as it is.
    @discardableResult
    func setAvatar(_ data: Data, mimeType: String, stripMetadata: Bool = true) async throws -> ComAtprotoRepoStrongRef {
        _ = try await did()
        let blob = try await uploadImage(data, mimeType: mimeType, stripMetadata: stripMetadata)
        return try await upsertProfile { existing in
            var profile = ProfileUpdate(existing)
            profile.avatar = blob
            return profile.record
        }
    }

    /// Sets the profile banner, uploading it first.
    ///
    /// Image metadata is removed before upload unless `stripMetadata` is
    /// `false`; see ``uploadImage(_:mimeType:stripMetadata:)``. The rest of
    /// the profile is left as it is.
    @discardableResult
    func setBanner(_ data: Data, mimeType: String, stripMetadata: Bool = true) async throws -> ComAtprotoRepoStrongRef {
        _ = try await did()
        let blob = try await uploadImage(data, mimeType: mimeType, stripMetadata: stripMetadata)
        return try await upsertProfile { existing in
            var profile = ProfileUpdate(existing)
            profile.banner = blob
            return profile.record
        }
    }

    /// The bytes to upload for an image: stripped of metadata unless the caller opted out.
    private static func preparedImage(_ data: Data, mimeType: String, stripMetadata: Bool) throws -> Data {
        let type = mimeType.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        guard type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("image/") else {
            throw BskyAgentError.invalidInput("Not an image media type: \(mimeType)")
        }
        guard stripMetadata else { return data }
        return try ImageMetadataStripper.stripMetadata(from: data, mimeType: mimeType)
    }

    // MARK: Blobs and handles

    /// Uploads a blob to the account's PDS exactly as given.
    ///
    /// **The bytes are sent unmodified, including any metadata embedded in
    /// them. A photo uploaded this way keeps its EXIF data, which can include
    /// the GPS position where it was taken.** To upload an image with its
    /// metadata removed, use ``uploadImage(_:mimeType:stripMetadata:)`` or
    /// ``post(_:images:stripImageMetadata:quote:reply:langs:labels:tags:createdAt:)``,
    /// or strip it yourself with ``ImageMetadataStripper/stripMetadata(from:mimeType:)``.
    ///
    /// `mimeType` is sent as the content type, so a PNG stays a PNG. Reference
    /// the returned blob from a record promptly; unreferenced blobs are
    /// garbage-collected by the PDS.
    ///
    /// - Parameters:
    ///   - data: The blob bytes.
    ///   - mimeType: The media type, for example `image/png` or `video/mp4`.
    func uploadBlob(_ data: Data, mimeType: String) async throws -> Blob {
        let nsid = "com.atproto.repo.uploadBlob"
        guard !mimeType.isEmpty, !mimeType.contains(where: \.isNewline) else {
            throw BskyAgentError.invalidInput("A blob needs a media type such as image/png")
        }
        let response = try await xrpc("POST", nsid, body: data, contentType: mimeType)
        guard let blob = try response.json(nsid: nsid)["blob"],
              let decoded = try? blob.decoded(as: Blob.self)
        else {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Missing blob")
        }
        return decoded
    }

    /// Resolves a handle to its DID through the PDS (`com.atproto.identity.resolveHandle`).
    ///
    /// - Returns: The DID, or `nil` when the handle does not resolve.
    func resolveHandle(_ handle: String) async throws -> DID? {
        let nsid = "com.atproto.identity.resolveHandle"
        let response: BskyXRPCResponse
        do {
            response = try await xrpcQuery(nsid, query: [URLQueryItem(name: "handle", value: handle)])
        } catch let error as BskyAgentError {
            if case let .xrpc(_, status, _, _) = error, status == 400 {
                return nil
            }
            throw error
        }
        guard let didString = try response.json(nsid: nsid)["did"]?.stringValue,
              let did = try? DID(didString: didString)
        else {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Missing or malformed did")
        }
        return did
    }
}
