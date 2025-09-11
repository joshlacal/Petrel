import Foundation

public extension ATProtoClient {
    /// Sets the `atproto-accept-labelers` header from an array of DIDs.
    /// - Parameter dids: Array of labeler DIDs to accept (no redaction).
    func setAcceptLabelers(dids: [String]) async {
        let pairs = dids.map { (did: $0, redact: false) }
        // Access the underlying NetworkService via the App namespace
        await self.app.networkService.setAcceptLabelers(pairs)
    }

    /// Sets the `atproto-accept-labelers` header with optional redaction flags per DID.
    /// - Parameter labelers: Tuples of (did, redact) to map to the RFC-8941 header format.
    func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)]) async {
        await self.app.networkService.setAcceptLabelers(labelers)
    }
}

