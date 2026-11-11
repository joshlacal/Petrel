import Foundation

/// Converts between `at://` URIs and the web addresses of the Bluesky app.
///
/// ```swift
/// let uri = try ATProtocolURI(uriString: "at://did:plc:abc/app.bsky.feed.post/3kabc")
/// BskyAppURL.url(for: uri, handle: "alice.example")
/// // https://bsky.app/profile/alice.example/post/3kabc
///
/// BskyAppURL.atURI(from: URL(string: "https://bsky.app/profile/alice.example/post/3kabc")!)
/// // at://alice.example/app.bsky.feed.post/3kabc
/// ```
///
/// Web addresses usually name the account by handle, so the `at://` URI
/// recovered from one may have a handle as its authority. Resolve it to a DID
/// (``BskyAgent/resolveHandle(_:)``) before using it as a durable reference.
public enum BskyAppURL {
    /// The host of the official web app.
    public static let host = "bsky.app"

    /// The collections that have a page in the app, and the path segment used for each.
    private static let recordSegments: [(collection: String, segment: String)] = [
        ("app.bsky.feed.post", "post"),
        ("app.bsky.feed.generator", "feed"),
        ("app.bsky.graph.list", "lists"),
    ]

    private static let starterPackCollection = "app.bsky.graph.starterpack"

    /// The web address of an account's profile.
    /// - Parameters:
    ///   - actor: A handle or DID.
    ///   - host: The web app host; defaults to `bsky.app`.
    public static func profileURL(_ actor: String, host: String = BskyAppURL.host) -> URL? {
        guard DID.isValidDID(actor) || Handle.isValidHandle(actor) else { return nil }
        return build(host: host, segments: ["profile", actor])
    }

    /// The web address showing the record or account an `at://` URI names.
    ///
    /// Supported: accounts, profile records, posts, feed generators, lists and
    /// starter packs.
    ///
    /// - Parameters:
    ///   - uri: The `at://` URI.
    ///   - handle: The account's handle, used in place of the DID for a
    ///     friendlier address. The DID form always works.
    ///   - host: The web app host; defaults to `bsky.app`.
    /// - Returns: The address, or `nil` when the app has no page for the URI.
    public static func url(for uri: ATProtocolURI, handle: String? = nil, host: String = BskyAppURL.host) -> URL? {
        guard !uri.isSpace else { return nil }
        let actor: String
        if let handle {
            guard Handle.isValidHandle(handle) else { return nil }
            actor = handle
        } else {
            actor = uri.authority
        }

        guard let collection = uri.collection else {
            return build(host: host, segments: ["profile", actor])
        }
        if collection == "app.bsky.actor.profile" {
            return build(host: host, segments: ["profile", actor])
        }
        guard let rkey = uri.recordKey else { return nil }
        if collection == starterPackCollection {
            return build(host: host, segments: ["starter-pack", actor, rkey])
        }
        guard let segment = recordSegments.first(where: { $0.collection == collection })?.segment else {
            return nil
        }
        return build(host: host, segments: ["profile", actor, segment, rkey])
    }

    /// The `at://` URI a Bluesky web address refers to.
    ///
    /// - Parameters:
    ///   - url: An `https://bsky.app/...` address of a profile, post, feed,
    ///     list or starter pack.
    ///   - hosts: Hosts accepted as the web app; defaults to `bsky.app`.
    /// - Returns: The URI, or `nil` when the address is not one of those pages.
    ///   The authority is whatever the address used: a handle or a DID.
    public static func atURI(from url: URL, hosts: Set<String> = [BskyAppURL.host]) -> ATProtocolURI? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let urlHost = url.host?.lowercased(), hosts.contains(urlHost)
        else {
            return nil
        }
        let segments = url.path.split(separator: "/").map(String.init)
        guard segments.count >= 2 else { return nil }

        let actor: String
        let collection: String?
        let rkey: String?
        switch (segments[0], segments.count) {
        case ("profile", 2):
            (actor, collection, rkey) = (segments[1], nil, nil)
        case ("profile", 4):
            guard let match = recordSegments.first(where: { $0.segment == segments[2] }) else { return nil }
            (actor, collection, rkey) = (segments[1], match.collection, segments[3])
        case ("starter-pack", 3), ("start", 3):
            (actor, collection, rkey) = (segments[1], starterPackCollection, segments[2])
        default:
            return nil
        }

        guard DID.isValidDID(actor) || Handle.isValidHandle(actor) else { return nil }
        var uriString = "at://\(actor)"
        if let collection, let rkey {
            uriString += "/\(collection)/\(rkey)"
        }
        return try? ATProtocolURI(uriString: uriString)
    }

    private static func build(host: String, segments: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/" + segments.joined(separator: "/")
        return components.url
    }
}
