// Expected failure: defaulted added parameters preserve ordinary calls,
// but do not preserve the exact old initializer function-reference signatures.
import Foundation
import Petrel

func oldInitializerReferences() {
    _ = Petrel.OAuthState.init(stateToken:codeVerifier:createdAt:initialIdentifier:targetPDSURL:ephemeralDPoPKey:parResponseNonce:bskyAppViewDID:bskyChatDID:)
    _ = Petrel.NetworkService.init(baseURL:authService:)
    _ = Petrel.AppBskyFeedDefs.ViewerState.init(repost:like:bookmarked:threadMuted:replyDisabled:embeddingDisabled:pinned:)
}
