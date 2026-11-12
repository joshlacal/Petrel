import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import PetrelOzone
import XCTest

/// The `PetrelOzone` product: the `tools.ozone` lexicons, generated as an overlay on Petrel
/// with `generator/manifests/petrel-ozone.json`.
final class OzoneOverlayTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        NetworkService.setNetworkTestProtocolClasses([FixtureStubURLProtocol.self])
    }

    override class func tearDown() {
        FixtureStubURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses(nil)
        super.tearDown()
    }

    override func tearDown() {
        FixtureStubURLProtocol.reset()
        super.tearDown()
    }

    private func ozone() -> ATProtoClient.Tools.Ozone {
        ATProtoClient.Tools(networkService: NetworkService(baseURL: URL(string: "https://example.com")!)).ozone
    }

    /// `tools.ozone.set.upsertSet` is the one endpoint in the standard namespaces whose input
    /// schema is a `ref`. Its body used to go out wrapped as `{"data": {...}}` (audit v-1).
    func testUpsertSetSendsTheSetItselfAsTheBody() async throws {
        FixtureStubURLProtocol.install(
            status: 200,
            body: #"{"name":"blocked-domains","setSize":0,"createdAt":"2026-07-15T12:00:00.000Z","updatedAt":"2026-07-15T12:00:00.000Z"}"#
        )

        let (status, view) = try await ozone().set.upsertSet(
            input: .init(name: "blocked-domains", description: "Domains to block")
        )

        XCTAssertEqual(status, 200)
        XCTAssertEqual(view?.name, "blocked-domains")
        let request = try XCTUnwrap(FixtureStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/xrpc/tools.ozone.set.upsertSet")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(FixtureStubURLProtocol.lastBody)
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: body) as? NSDictionary,
            ["name": "blocked-domains", "description": "Domains to block"]
        )
    }

    func testAnOzoneErrorIsThrownTyped() async throws {
        FixtureStubURLProtocol.install(status: 400, body: #"{"error":"SetNotFound","message":"no such set"}"#)

        do {
            _ = try await ozone().set.deleteSet(input: .init(name: "missing"))
            XCTFail("a 400 response must throw")
        } catch let error as ATProtoError<ToolsOzoneSetDeleteSet.Error> {
            XCTAssertEqual(error.error, .setNotFound)
            XCTAssertEqual(error.message, "no such set")
        }
    }

    func testRegisteringTheModuleTypesOzoneValuesInsideUntypedData() throws {
        PetrelOzoneLexicons.register()

        let json = Data(#"{"$type":"tools.ozone.set.defs#set","name":"blocked-domains","future":true}"#.utf8)
        let container = try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        let set = try XCTUnwrap(container.decoded(ToolsOzoneSetDefs.Set.self))

        XCTAssertEqual(set.name, "blocked-domains")
        XCTAssertEqual(set.extraFields, ["future": .bool(true)])
    }
}
