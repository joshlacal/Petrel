import Foundation

/// A generated subscription message union that knows which message types its Lexicon declares.
///
/// The event-stream specification asks clients to ignore frames whose type they do not
/// recognise, so a consumer keeps working when a service adds a message type.
/// `NetworkService.subscribe(endpoint:parameters:)` reads ``knownMessageTypes`` and skips any
/// frame whose fully-qualified type (for example `com.atproto.sync.subscribeRepos#commit`)
/// is not in the set, instead of ending the stream with a decoding error.
public protocol XRPCSubscriptionMessage {
    /// The fully-qualified message types (`<nsid>#<name>`) this union can decode.
    static var knownMessageTypes: Set<String> { get }
}
