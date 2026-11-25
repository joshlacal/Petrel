// Stand-ins for the things documentation-comment examples refer to but do not define: an
// application's own types and helper functions. They exist only so the examples type-check
// (Scripts/validate-documentation.sh); nothing here ships in a product.

import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo

/// A key-management service that signs a digest remotely.
struct StubKMS: Sendable {
    func signECDSA(digest _: Data) async throws -> Data { Data() }
}

struct StubKeychain {
    func save(_: Data) {}
}

/// An incoming HTTP request in whatever server framework the application uses.
struct StubHTTPRequest {
    var headers: [String: String] = [:]
}

struct StubKeyDocument: Sendable {
    func key(named _: String) throws -> ATProtoPublicKey { fatalError("type-check only") }
}

struct StubKeyDirectory: Sendable {
    func document(for _: String, bypassCache _: Bool) async throws -> StubKeyDocument { StubKeyDocument() }
}

struct StubDocumentDirectory: Sendable {
    func document(for _: String, bypassCache _: Bool) async throws -> DIDDocument { fatalError("type-check only") }
}

/// A commit event as a firehose consumer holds it.
struct StubCommitEvent {
    var blocks = Data()
    var commitCID: CID
    var repo = ""
    var rev = ""
}

func index(_: some Any, _: some Any) {}
func handleAutoLogout(did _: some Any, reason _: some Any) async {}
func showReauthenticationPrompt() async {}
func showCover(canReveal _: Bool) {}
