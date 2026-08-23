import Foundation
import XCTest
@testable import PetrelFirehose

final class PublicFirehoseEventTests: XCTestCase {
  private let did = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"

  func testSourceKeyFormats() {
    XCTAssertEqual(PublicFirehoseSourceKey.commit(did: did, commitCID: "bafy1"), "\(did)|commit|bafy1")
    XCTAssertEqual(PublicFirehoseSourceKey.syncOversize(did: did, commitCID: "bafy1"), "\(did)|sync|oversize|bafy1")
    XCTAssertEqual(PublicFirehoseSourceKey.syncManual(did: did, requestUUID: "ABC-DEF"), "\(did)|sync|manual|abc-def")
    XCTAssertEqual(PublicFirehoseSourceKey.syncActivation(did: did, operationID: "op-1"), "\(did)|sync|activation|op-1")
    XCTAssertEqual(PublicFirehoseSourceKey.syncReactivation(did: did, operationID: "op-1"), "\(did)|sync|reactivation|op-1")
    XCTAssertEqual(PublicFirehoseSourceKey.account(did: did, operationID: "op-1"), "\(did)|account|op-1")
    XCTAssertEqual(PublicFirehoseSourceKey.identity(did: did, plcOperationCID: "bafy1"), "\(did)|identity|bafy1")
  }

  func testLifecycleBatchKeyIsDIDNamespaced() {
    let operationID = "op-1"
    let first = PublicFirehoseSourceKey.lifecycleBatch(did: "did:plc:aaa", operationID: operationID)
    let second = PublicFirehoseSourceKey.lifecycleBatch(did: "did:plc:bbb", operationID: operationID)
    XCTAssertEqual(first, "did:plc:aaa|lifecycle|op-1")
    XCTAssertEqual(second, "did:plc:bbb|lifecycle|op-1")
    XCTAssertNotEqual(first, second)
  }

  func testJSONRoundTripWithOptionalFieldsPresent() throws {
    let op = PublicFirehoseRepoOp(action: .update, path: "app.bsky.feed.post/3k/1", cid: "bafy2", prev: "bafy1")
    let material = PublicFirehoseCommitMaterial(
      did: did,
      rev: "3kabc",
      since: "2026-08-04T12:00:00.000Z",
      commitCID: "bafy3",
      prevDataCID: "bafy2",
      ops: [op],
      time: "2026-08-04T12:00:00.000Z"
    )
    let data = try JSONEncoder().encode(material)
    let decoded = try JSONDecoder().decode(PublicFirehoseCommitMaterial.self, from: data)
    XCTAssertEqual(decoded, material)
    XCTAssertEqual(decoded.since, "2026-08-04T12:00:00.000Z")
    XCTAssertEqual(decoded.prevDataCID, "bafy2")
    XCTAssertEqual(decoded.ops, [op])
  }

  func testJSONRoundTripWithOptionalFieldsNil() throws {
    let op = PublicFirehoseRepoOp(action: .create, path: "app.bsky.feed.post/3k/1", cid: "bafy1", prev: nil)
    let material = PublicFirehoseCommitMaterial(
      did: did,
      rev: "3kabc",
      since: nil,
      commitCID: "bafy1",
      prevDataCID: nil,
      ops: [op],
      time: "2026-08-04T12:00:00.000Z"
    )
    let data = try JSONEncoder().encode(material)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertNil(json["since"])
    XCTAssertNil(json["prevDataCID"])
    let encodedOps = try XCTUnwrap(json["ops"] as? [[String: Any]])
    let encodedOp = try XCTUnwrap(encodedOps.first)
    XCTAssertEqual(encodedOp["cid"] as? String, "bafy1")
    XCTAssertNil(encodedOp["prev"])
    let decoded = try JSONDecoder().decode(PublicFirehoseCommitMaterial.self, from: data)
    XCTAssertEqual(decoded, material)
    XCTAssertNil(decoded.since)
    XCTAssertNil(decoded.prevDataCID)
  }

  func testTypedRepositoryActionsRoundTrip() throws {
    let actions: [PublicFirehoseRepoAction] = [.create, .update, .delete]
    let data = try JSONEncoder().encode(actions)
    XCTAssertEqual(try JSONDecoder().decode([PublicFirehoseRepoAction].self, from: data), actions)
  }

  func testAccountStatusRoundTrip() throws {
    let statuses: [PublicFirehoseAccountStatus] = [.deactivated, .suspended, .takendown, .desynchronized, .throttled, .deleted]
    let data = try JSONEncoder().encode(statuses)
    XCTAssertEqual(try JSONDecoder().decode([PublicFirehoseAccountStatus].self, from: data), statuses)
    let active = PublicFirehoseAccountMaterial(did: did, active: true, status: nil, time: "2026-08-04T12:00:00.000Z")
    let inactive = PublicFirehoseAccountMaterial(did: did, active: false, status: .deleted, time: "2026-08-04T12:00:00.000Z")
    XCTAssertEqual(try JSONDecoder().decode(PublicFirehoseAccountMaterial.self, from: JSONEncoder().encode(active)), active)
    XCTAssertEqual(try JSONDecoder().decode(PublicFirehoseAccountMaterial.self, from: JSONEncoder().encode(inactive)), inactive)
  }

  func testExactDateEncoding() {
    let date = Date(timeIntervalSince1970: 1_785_844_800)
    XCTAssertEqual(PublicFirehoseTime.encode(date), "2026-08-04T12:00:00.000Z")
  }

  func testDateEncodingWithFractionalSeconds() {
    let date = Date(timeIntervalSince1970: 1_785_844_800.5)
    XCTAssertEqual(PublicFirehoseTime.encode(date), "2026-08-04T12:00:00.500Z")
  }

  func testMicrosecondConversion() throws {
    let date = Date(timeIntervalSince1970: 1_785_844_800)
    XCTAssertEqual(try PublicFirehoseTime.microseconds(date), 1_785_844_800_000_000)
  }

  func testMicrosecondsRejectsInvalidDates() {
    XCTAssertThrowsError(try PublicFirehoseTime.microseconds(Date(timeIntervalSince1970: -1))) { error in
      XCTAssertEqual(error as? PublicFirehoseTimeError, .outOfRange)
    }
    XCTAssertThrowsError(try PublicFirehoseTime.microseconds(Date(timeIntervalSince1970: .infinity))) { error in
      XCTAssertEqual(error as? PublicFirehoseTimeError, .outOfRange)
    }
    XCTAssertThrowsError(try PublicFirehoseTime.microseconds(Date(timeIntervalSince1970: .nan))) { error in
      XCTAssertEqual(error as? PublicFirehoseTimeError, .outOfRange)
    }
  }
}
