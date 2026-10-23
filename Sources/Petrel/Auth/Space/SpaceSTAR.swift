import CoreFoundation
import Foundation
import PetrelCrypto
import SwiftCBOR

public enum SpaceVerificationError: Error, Sendable, Equatable {
    case malformedHeader
    case invalidCommit
    case invalidArchive
    case boundsExceeded
    case invalidRecord
    case digestMismatch
    case missingKEMKey
}

/// A complete, verified repository snapshot. No records escape until every frame
/// and the final set digest have been validated.
public struct VerifiedSpaceRepository: Sendable {
    public struct Record: Sendable {
        public let path: String
        public let cid: CID
        public let bytes: Data
    }

    public let revision: String
    public let data: Data
    public let records: [Record]
}

public enum SpaceSTAR {
    public static let maximumRecordBytes = 1_048_576
    public static let defaultMaximumArchiveBytes = 128 * 1_048_576

    /// Verify an October 22 STAR archive. A nil MAC context is only appropriate
    /// for the repository owner's OAuth response, whose transport authenticates it.
    public static func verify(
        archive: Data, space: SpaceRef, repo: String,
        sharedSecret: Data? = nil, mac: Data? = nil,
        maximumArchiveBytes: Int = defaultMaximumArchiveBytes
    ) throws -> VerifiedSpaceRepository {
        guard archive.count <= maximumArchiveBytes else { throw SpaceVerificationError.boundsExceeded }
        var cursor = Cursor(bytes: archive)
        guard try cursor.take(4) == Data([0x2A, 0x6C, 1, 0]) else { throw SpaceVerificationError.invalidArchive }
        let metadata = try cursor.frame(limit: 65536)
        let value = try canonicalObject(metadata)
        guard value["$type"] as? String == "atproto-space-repo",
              Set(value.keys) == ["$type", "ver", "repo", "space", "rev", "data"]
        else {
            throw SpaceVerificationError.invalidCommit
        }
        let commit = try SpaceResponseVerifier.commitFields(value, space: space, repo: repo)
        if let sharedSecret, let mac {
            try SpaceMAC.verify(mac: mac, expected: SpaceMAC.commit(
                sharedSecret: sharedSecret, space: space.uriString(), repo: repo, rev: commit.rev, data: commit.data
            ))
        } else if sharedSecret != nil || mac != nil {
            throw SpaceVerificationError.malformedHeader
        }
        var records: [VerifiedSpaceRepository.Record] = []
        var previous = Data()
        var hash = SpaceSetHash()
        while !cursor.isAtEnd {
            let pathBytes = try cursor.frame(limit: 830)
            guard previous.lexicographicallyPrecedes(pathBytes),
                  let path = String(data: pathBytes, encoding: .utf8) else { throw SpaceVerificationError.invalidArchive }
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count == 2,
                  (try? NSID(nsidString: String(components[0]))) != nil,
                  validRecordKey(String(components[1])) else { throw SpaceVerificationError.invalidRecord }
            previous = pathBytes
            let bytes = try cursor.frame(limit: maximumRecordBytes)
            _ = try canonicalObject(bytes)
            let cid = CID.fromDAGCBOR(bytes)
            hash.add(path: path, cid: cid.string)
            records.append(.init(path: path, cid: cid, bytes: bytes))
        }
        guard hash.digest == commit.data else { throw SpaceVerificationError.digestMismatch }
        return VerifiedSpaceRepository(revision: commit.rev, data: commit.data, records: records)
    }

    static func canonicalObject(_ bytes: Data) throws -> [String: Any] {
        try DAGCBOR.decodeCBORPreflight(bytes)
        guard let cbor = try CBOR.decode(Array(bytes)),
              let object = try DAGCBOR.decodeCBORItem(cbor) as? [String: Any],
              try DAGCBOR.encodeValue(cborValue(object)) == bytes else { throw SpaceVerificationError.invalidRecord }
        return object
    }

    private static func cborValue(_ value: Any) throws -> Any {
        if let cid = value as? CID { return CIDAsLink(cid: cid, representation: .link) }
        if let object = value as? [String: Any] { return try object.mapValues { try cborValue($0) } }
        if let array = value as? [Any] { return try array.map { try cborValue($0) } }
        return value
    }

    static func validRecordKey(_ value: String) -> Bool {
        (1 ... 512).contains(value.utf8.count) && value != "." && value != ".." && value.utf8.allSatisfy {
            (48 ... 57).contains($0) || (65 ... 90).contains($0) || (97 ... 122).contains($0) || [45, 46, 95, 58, 126].contains($0)
        }
    }

    private struct Cursor {
        let bytes: Data
        var offset = 0
        var isAtEnd: Bool {
            offset == bytes.count
        }

        mutating func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= bytes.count - offset else { throw SpaceVerificationError.invalidArchive }
            defer { offset += count }
            return bytes.subdata(in: offset ..< offset + count)
        }

        mutating func frame(limit: Int) throws -> Data {
            var length: UInt64 = 0
            for index in 0 ..< 10 {
                let byte = try take(1)[0]
                guard index < 9 || byte < 2 else { throw SpaceVerificationError.invalidArchive }
                length |= UInt64(byte & 127) << (index * 7)
                if byte & 128 == 0 {
                    guard index == 0 || byte != 0 else { throw SpaceVerificationError.invalidArchive }
                    guard length <= UInt64(limit) else { throw SpaceVerificationError.boundsExceeded }
                    return try take(Int(length))
                }
            }
            throw SpaceVerificationError.invalidArchive
        }
    }
}

enum SpaceResponseVerifier {
    static func commitFields(_ value: [String: Any], space: SpaceRef, repo: String) throws -> (rev: String, data: Data) {
        guard let version = value["ver"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version.intValue == 1, version.doubleValue == 1,
              value["repo"] as? String == repo, value["space"] as? String == space.uriString(),
              let rev = value["rev"] as? String, (try? TID(tidString: rev)) != nil
        else {
            throw SpaceVerificationError.invalidCommit
        }
        let digest: Data?
        if let raw = value["data"] as? Data { digest = raw }
        else if let wrapper = value["data"] as? [String: String], wrapper.count == 1,
                let encoded = wrapper["$bytes"] { digest = try? decodeBytes(encoded) }
        else { digest = nil }
        guard let digest, digest.count == 32 else { throw SpaceVerificationError.invalidCommit }
        return (rev, digest)
    }

    static func verifyJSON(_ bytes: Data, method: String, url: URL, space: SpaceRef, repo: String, secret: Data, macHeader: String?) throws {
        guard let value = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw SpaceVerificationError.invalidCommit }
        if method == "getRecord" {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let collection = items.first(where: { $0.name == "collection" })?.value,
                  let rkey = items.first(where: { $0.name == "rkey" })?.value else { throw SpaceVerificationError.invalidRecord }
            let uri = "\(space.uriString())/\(repo)/\(collection)/\(rkey)"
            guard value["uri"] as? String == uri, let cidString = value["cid"] as? String,
                  let cid = try? CID.parse(cidString), let record = value["value"] as? [String: Any]
            else {
                throw SpaceVerificationError.invalidRecord
            }
            let mac = try SpaceMACHeader.parse(macHeader, type: "atproto-space-record")
            try SpaceMAC.verify(mac: mac, expected: SpaceMAC.record(sharedSecret: secret, uri: uri, cid: cid.bytes))
            let encoded = try DAGCBOR.encodeValue(lexiconValue(record))
            guard encoded.count <= SpaceSTAR.maximumRecordBytes, CID.fromDAGCBOR(encoded) == cid else { throw SpaceVerificationError.invalidRecord }
            return
        }
        guard let commit = value["commit"] as? [String: Any] else {
            if method == "listRepoOps", value["commit"] == nil, macHeader == nil { return }
            throw SpaceVerificationError.invalidCommit
        }
        let fields = try commitFields(commit, space: space, repo: repo)
        let mac = try SpaceMACHeader.parse(macHeader, type: "atproto-space-repo")
        try SpaceMAC.verify(mac: mac, expected: SpaceMAC.commit(sharedSecret: secret, space: space.uriString(), repo: repo, rev: fields.rev, data: fields.data))
    }

    private static func decodeBytes(_ encoded: String) throws -> Data {
        let json = try JSONSerialization.data(withJSONObject: ["$bytes": encoded])
        return try JSONDecoder().decode(Bytes.self, from: json).data
    }

    private static func lexiconValue(_ value: Any) throws -> Any {
        if let object = value as? [String: Any] {
            if object.count == 1, let text = object["$bytes"] as? String { return try decodeBytes(text) }
            if object.count == 1, let text = object["$link"] as? String, let cid = try? CID.parse(text) { return CIDAsLink(cid: cid, representation: .link) }
            return try object.mapValues { try lexiconValue($0) }
        }
        if let array = value as? [Any] { return try array.map { try lexiconValue($0) } }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
            let text = number.stringValue
            if let integer = Int64(text) { return integer }
            if let integer = UInt64(text) { return integer }
            throw SpaceVerificationError.invalidRecord
        }
        return value
    }
}
