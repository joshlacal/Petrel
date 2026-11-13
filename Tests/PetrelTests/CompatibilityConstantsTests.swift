import Foundation
@testable import Petrel
import Testing

/// Identifiers that are already persisted on users' devices keep their historical values even
/// though the code names them neutrally. Changing one silently orphans stored data.
@Suite("Persisted compatibility constants")
struct CompatibilityConstantsTests {
    @Test("The pre-multi-account gateway session namespace keeps its stored value")
    func legacyGlobalGatewaySessionNamespaceIsStable() {
        #expect(KeychainStorage.legacyGlobalGatewaySessionNamespace == "catbird.gateway")
    }

    @Test("The strict-decoding user-info key is the documented one")
    func strictDecodingKeyIsNeutral() {
        #expect(CodingUserInfoKey.atprotoStrictDecoding.rawValue == "Petrel.atprotoStrictDecoding")
    }
}
