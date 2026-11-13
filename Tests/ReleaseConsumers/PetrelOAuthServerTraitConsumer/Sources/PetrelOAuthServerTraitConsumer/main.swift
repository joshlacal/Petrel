import PetrelOAuthServer
import PetrelOAuthServerLexicon
import PetrelOAuthServerNIO

// The fetcher refuses a transport that does not pin connections, so building
// one here proves the consumer got the real transport and not the stub.
let fetcher = try OAuthRemoteDocumentFetcher(
    policy: OAuthRemoteFetchPolicy(),
    transport: PinnedNIOOAuthRemoteTransport()
)
// The authenticated Lexicon resolver for `include:` scopes, over the same
// pinned fetcher, as the guide wires it.
_ = try AuthenticatedOAuthLexiconResolver(fetcher: fetcher)
print("PinnedNIOOAuthRemoteTransport OK")
