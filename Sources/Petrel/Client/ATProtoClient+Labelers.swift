import Foundation

/// One entry of the `atproto-accept-labelers` request header or the
/// `atproto-content-labelers` response header: a labeler DID and its flags.
///
/// The header syntax is RFC 9651 section 3.1.2 as profiled by the AT Protocol
/// label specification: comma-separated DIDs, each optionally followed by
/// `;redact`.
public struct AcceptedLabeler: Sendable, Hashable, CustomStringConvertible {
    /// The labeler service DID.
    public let did: DID

    /// Whether the service hydrating labels should redact content this labeler
    /// marks `!takedown` or `!suspend` instead of only labeling it.
    public let redact: Bool

    /// Creates a header entry.
    public init(did: DID, redact: Bool = false) {
        self.did = did
        self.redact = redact
    }

    public var description: String {
        redact ? "\(did.didString());redact" : did.didString()
    }

    /// Collapses repeated DIDs into one entry each, keeping first-seen order.
    /// A DID listed both with and without `redact` keeps `redact`, as the
    /// specification requires of services.
    public static func deduplicated(_ labelers: [AcceptedLabeler]) -> [AcceptedLabeler] {
        var order: [DID] = []
        var redact: [DID: Bool] = [:]
        for labeler in labelers {
            if let existing = redact[labeler.did] {
                redact[labeler.did] = existing || labeler.redact
            } else {
                order.append(labeler.did)
                redact[labeler.did] = labeler.redact
            }
        }
        return order.map { AcceptedLabeler(did: $0, redact: redact[$0] ?? false) }
    }

    /// Formats entries as a header value. Repeated DIDs are merged first.
    ///
    /// An empty list yields an empty string. Sent as the header value, that
    /// means "apply no labels", which differs from omitting the header.
    public static func headerValue(for labelers: [AcceptedLabeler]) -> String {
        deduplicated(labelers).map(\.description).joined(separator: ", ")
    }

    /// Parses an `atproto-accept-labelers` or `atproto-content-labelers` value.
    ///
    /// Entries whose DID is not syntactically valid are skipped; parameters
    /// other than `redact` are ignored. Repeated DIDs are merged.
    public static func parseHeader(_ value: String) -> [AcceptedLabeler] {
        var parsed: [AcceptedLabeler] = []
        for item in value.split(separator: ",") {
            let parts = item.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let first = parts.first, let did = try? DID(didString: first) else { continue }
            parsed.append(AcceptedLabeler(did: did, redact: parts.dropFirst().contains("redact")))
        }
        return deduplicated(parsed)
    }
}

public extension ATProtoClient {
    /// Sets the labelers requested on every call (`atproto-accept-labelers`).
    ///
    /// Passing an empty array sends the header with no value, which asks the
    /// service to apply no labels at all. To go back to the service's default
    /// labelers, call ``clearLabelers()``.
    ///
    /// Repeated DIDs are merged, keeping `redact` if any occurrence has it.
    /// Services may limit how many labelers one request can name (the Bluesky
    /// AppView rejects more than 20); the list is sent as given.
    func configureLabelers(_ labelers: [AcceptedLabeler]) async {
        await networkService.setHeader(
            name: "atproto-accept-labelers",
            value: AcceptedLabeler.headerValue(for: labelers)
        )
    }

    /// Removes the `atproto-accept-labelers` header so the service applies its default labelers.
    func clearLabelers() async {
        await networkService.removeHeader(name: "atproto-accept-labelers")
    }

    /// The labelers currently requested on every call, or `nil` when the
    /// header is not being sent.
    func configuredLabelers() async -> [AcceptedLabeler]? {
        guard let value = await networkService.getHeader(name: "atproto-accept-labelers") else {
            return nil
        }
        return AcceptedLabeler.parseHeader(value)
    }

    /// Sets the `atproto-accept-labelers` header from an array of DIDs.
    /// - Parameter dids: Array of labeler DIDs to accept (no redaction).
    @available(*, deprecated, message: "Use configureLabelers(_:) with typed AcceptedLabeler values; an empty list here removes the header instead of sending it empty")
    func setAcceptLabelers(dids: [String]) async {
        let pairs = dids.map { (did: $0, redact: false) }
        await networkService.setAcceptLabelers(pairs)
    }

    /// Sets the `atproto-accept-labelers` header with optional redaction flags per DID.
    /// - Parameter labelers: Tuples of (did, redact) to map to the RFC 9651 header format.
    @available(*, deprecated, message: "Use configureLabelers(_:) with typed AcceptedLabeler values; an empty list here removes the header instead of sending it empty")
    func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)]) async {
        await networkService.setAcceptLabelers(labelers)
    }
}
