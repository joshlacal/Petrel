import Foundation
import Petrel
import PetrelRepo

public enum RelayFrameDecoder {
  public static func decode(_ frame: Data) throws -> RelayEvent {
    guard frame.count <= FirehoseFrameLimits.maximumFrameBytes else {
      throw RelayVerifierError.frameTooLarge
    }
    var reader = CanonicalRelayCBORReader(frame)
    let header: RelayCBORValue
    let body: RelayCBORValue
    do {
      header = try reader.read()
      body = try reader.read()
    } catch let error as RelayCBORReaderError {
      throw error.publicError
    }
    guard reader.isAtEnd else { throw RelayVerifierError.trailingFrameBytes }
    return try decode(header: header, body: body)
  }

  private static func decode(
    header: RelayCBORValue,
    body: RelayCBORValue
  ) throws -> RelayEvent {
    let headerMap = try map(header)
    guard let op = headerMap.signedInteger("op") else {
      throw RelayVerifierError.invalidFrameHeader
    }
    if op == -1 {
      guard headerMap.keys == Set(["op"]) else {
        throw RelayVerifierError.invalidFrameHeader
      }
      return .error(try decodeError(body))
    }
    guard op == 1,
          headerMap.keys == Set(["op", "t"]),
          let type = headerMap.text("t") else {
      throw RelayVerifierError.invalidFrameHeader
    }
    switch type {
    case "#identity": return .identity(try decodeIdentity(body))
    case "#account": return .account(try decodeAccount(body))
    case "#sync": return .sync(try decodeSync(body))
    case "#commit": return .commit(try decodeCommit(body))
    case "#info": return .info(try decodeInfo(body))
    default: throw RelayVerifierError.unknownEventKind
    }
  }

  private static func decodeIdentity(_ body: RelayCBORValue) throws -> RelayIdentityEvent {
    let value = try map(body)
    try value.requireKeys(required: ["seq", "did", "time"], optional: ["handle"])
    return .init(
      seq: try sequence(value["seq"]),
      did: try did(value["did"]),
      time: try requiredText(value["time"]),
      handle: try optionalText(value["handle"])
    )
  }

  private static func decodeAccount(_ body: RelayCBORValue) throws -> RelayAccountEvent {
    let value = try map(body)
    try value.requireKeys(
      required: ["seq", "did", "time", "active"],
      optional: ["status"]
    )
    guard case let .boolean(active)? = value["active"] else {
      throw RelayVerifierError.invalidEventBody
    }
    let status = try optionalText(value["status"])
    let allowed = Set([
      "deactivated", "suspended", "takendown", "desynchronized", "throttled", "deleted",
    ])
    guard active == (status == nil), status.map(allowed.contains) ?? true else {
      throw RelayVerifierError.invalidAccountStatus
    }
    return .init(
      seq: try sequence(value["seq"]),
      did: try did(value["did"]),
      time: try requiredText(value["time"]),
      active: active,
      status: status
    )
  }

  private static func decodeSync(_ body: RelayCBORValue) throws -> RelaySyncEvent {
    let value = try map(body)
    try value.requireKeys(required: ["seq", "did", "blocks", "rev", "time"])
    guard case let .bytes(blocks)? = value["blocks"] else {
      throw RelayVerifierError.invalidEventBody
    }
    guard blocks.count <= FirehoseFrameLimits.maximumSyncBlocksBytes else {
      throw RelayVerifierError.syncBlocksTooLarge
    }
    let rev = try revision(value["rev"])
    return .init(
      seq: try sequence(value["seq"]),
      did: try did(value["did"]),
      blocks: blocks,
      rev: rev,
      time: try requiredText(value["time"])
    )
  }

  private static func decodeCommit(_ body: RelayCBORValue) throws -> RelayCommitEvent {
    let value = try map(body)
    try value.requireKeys(
      required: [
        "seq", "rebase", "tooBig", "repo", "commit", "rev", "since",
        "blocks", "ops", "blobs", "time",
      ],
      optional: ["prevData"]
    )
    guard case .boolean(false)? = value["rebase"],
          case .boolean(false)? = value["tooBig"],
          case let .bytes(blocks)? = value["blocks"],
          case let .array(opValues)? = value["ops"],
          case let .array(blobValues)? = value["blobs"] else {
      throw RelayVerifierError.invalidEventBody
    }
    guard blocks.count <= FirehoseFrameLimits.maximumCommitBlocksBytes else {
      throw RelayVerifierError.commitBlocksTooLarge
    }
    guard opValues.count <= FirehoseFrameLimits.maximumOps else {
      throw RelayVerifierError.tooManyOperations
    }
    for blob in blobValues {
      _ = try cid(blob)
    }
    let since: String?
    switch value["since"] {
    case .null?: since = nil
    case .text?: since = try revision(value["since"])
    default: throw RelayVerifierError.invalidEventBody
    }
    let prevDataCID: CID?
    if let encoded = value["prevData"] {
      prevDataCID = try repositoryCID(encoded)
    } else {
      prevDataCID = nil
    }
    return .init(
      seq: try sequence(value["seq"]),
      repo: try did(value["repo"]),
      commitCID: try repositoryCID(value["commit"]),
      rev: try revision(value["rev"]),
      since: since,
      blocks: blocks,
      ops: try opValues.map(decodeOperation),
      prevDataCID: prevDataCID,
      time: try requiredText(value["time"])
    )
  }

  private static func decodeOperation(_ encoded: RelayCBORValue) throws -> RelayRepoOp {
    let value = try map(encoded)
    try value.requireKeys(required: ["action", "path", "cid"], optional: ["prev"])
    guard let actionText = value.text("action"),
          let action = RelayRepoAction(rawValue: actionText),
          let pathText = value.text("path") else {
      throw RelayVerifierError.invalidRepositoryOperation
    }
    _ = try repositoryPath(pathText)
    let current: CID?
    switch value["cid"] {
    case .null?: current = nil
    case .cidLink?: current = try repositoryCID(value["cid"])
    default: throw RelayVerifierError.invalidRepositoryOperation
    }
    let previous: CID?
    if let encoded = value["prev"] {
      previous = try repositoryCID(encoded)
    } else {
      previous = nil
    }
    switch action {
    case .create where current != nil && previous == nil: break
    case .update where current != nil && previous != nil: break
    case .delete where current == nil && previous != nil: break
    default: throw RelayVerifierError.invalidRepositoryOperation
    }
    return .init(action: action, path: pathText, cid: current, prev: previous)
  }

  private static func decodeInfo(_ body: RelayCBORValue) throws -> RelayInfoEvent {
    let value = try map(body)
    try value.requireKeys(required: ["name"], optional: ["message"])
    return .init(
      name: try requiredText(value["name"]),
      message: try optionalText(value["message"])
    )
  }

  private static func decodeError(_ body: RelayCBORValue) throws -> RelayErrorEvent {
    let value = try map(body)
    try value.requireKeys(required: ["error"], optional: ["message"])
    return .init(
      error: try requiredText(value["error"]),
      message: try optionalText(value["message"])
    )
  }

  private static func map(_ value: RelayCBORValue) throws -> RelayCBORMap {
    guard case let .map(map) = value else { throw RelayVerifierError.invalidEventBody }
    return map
  }

  private static func requiredText(_ value: RelayCBORValue?) throws -> String {
    guard case let .text(text)? = value, !text.isEmpty else {
      throw RelayVerifierError.invalidEventBody
    }
    return text
  }

  private static func optionalText(_ value: RelayCBORValue?) throws -> String? {
    guard let value else { return nil }
    if case .null = value { return nil }
    return try requiredText(value)
  }

  private static func sequence(_ value: RelayCBORValue?) throws -> Int64 {
    let seq: Int64
    switch value {
    case let .unsigned(raw)?:
      guard raw <= UInt64(Int64.max) else { throw RelayVerifierError.sequenceOutOfRange }
      seq = Int64(raw)
    case let .signed(raw)?: seq = raw
    default: throw RelayVerifierError.invalidEventBody
    }
    guard seq >= 1, seq <= FirehoseFrameLimits.maximumSequence else {
      throw RelayVerifierError.sequenceOutOfRange
    }
    return seq
  }

  private static func did(_ value: RelayCBORValue?) throws -> String {
    let text = try requiredText(value)
    guard (try? DID(didString: text)) != nil else {
      throw RelayVerifierError.invalidEventBody
    }
    return text
  }

  private static func revision(_ value: RelayCBORValue?) throws -> String {
    let text = try requiredText(value)
    guard (try? PublicRepositoryTID(text)) != nil else {
      throw RelayVerifierError.invalidEventBody
    }
    return text
  }

  private static func cid(_ value: RelayCBORValue) throws -> CID {
    guard case let .cidLink(cid) = value else {
      throw RelayVerifierError.invalidCIDLink
    }
    return cid
  }

  private static func repositoryCID(_ value: RelayCBORValue?) throws -> CID {
    guard let value else { throw RelayVerifierError.invalidCIDLink }
    let candidate = try cid(value)
    do {
      try PublicRepositoryCID.validate(candidate)
    } catch {
      throw RelayVerifierError.invalidCIDLink
    }
    return candidate
  }

  private static func repositoryPath(_ value: String) throws -> PublicRepositoryPath {
    guard let slash = value.firstIndex(of: "/") else {
      throw RelayVerifierError.invalidRepositoryOperation
    }
    do {
      return try PublicRepositoryPath(
        collection: String(value[..<slash]),
        recordKey: String(value[value.index(after: slash)...])
      )
    } catch {
      throw RelayVerifierError.invalidRepositoryOperation
    }
  }
}

indirect enum RelayCBORValue {
  case unsigned(UInt64)
  case signed(Int64)
  case text(String)
  case bytes(Data)
  case boolean(Bool)
  case null
  case array([RelayCBORValue])
  case map(RelayCBORMap)
  case cidLink(CID)
}

struct RelayCBORMap {
  private let storage: [String: RelayCBORValue]

  init(_ entries: [(String, RelayCBORValue)]) {
    storage = Dictionary(uniqueKeysWithValues: entries)
  }

  var keys: Set<String> { Set(storage.keys) }

  subscript(_ key: String) -> RelayCBORValue? { storage[key] }

  func text(_ key: String) -> String? {
    guard case let .text(value)? = storage[key] else { return nil }
    return value
  }

  func signedInteger(_ key: String) -> Int64? {
    switch storage[key] {
    case let .unsigned(value) where value <= UInt64(Int64.max): Int64(value)
    case let .signed(value): value
    default: nil
    }
  }

  func requireKeys(required: Set<String>, optional: Set<String> = []) throws {
    guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)) else {
      throw RelayVerifierError.invalidEventBody
    }
  }
}

enum RelayCBORReaderError: Error, Equatable {
  case truncated
  case invalid
  case nonCanonical
  case invalidCID

  var publicError: RelayVerifierError {
    switch self {
    case .truncated: .truncatedFrame
    case .invalid: .invalidCBOR
    case .nonCanonical: .nonCanonicalCBOR
    case .invalidCID: .invalidCIDLink
    }
  }
}

struct CanonicalRelayCBORReader {
  private let bytes: [UInt8]
  private var offset = 0
  private var nodeCount = 0

  init(_ data: Data) {
    bytes = Array(data)
  }

  var isAtEnd: Bool { offset == bytes.count }

  mutating func read(depth: Int = 0) throws -> RelayCBORValue {
    guard depth <= FirehoseFrameLimits.maximumDepth else { throw RelayCBORReaderError.invalid }
    nodeCount += 1
    guard nodeCount <= FirehoseFrameLimits.maximumAggregateNodes else { throw RelayCBORReaderError.invalid }
    guard let initial = readByte() else { throw RelayCBORReaderError.truncated }
    let major = initial >> 5
    let argument = try readArgument(initial)
    switch major {
    case 0: return .unsigned(argument)
    case 1:
      if argument == UInt64(Int64.max) + 1 { return .signed(Int64.min) }
      guard argument <= UInt64(Int64.max) else { throw RelayCBORReaderError.invalid }
      return .signed(-1 - Int64(argument))
    case 2: return .bytes(Data(try payload(argument)))
    case 3:
      let bytes = Data(try payload(argument))
      guard let text = String(data: bytes, encoding: .utf8) else {
        throw RelayCBORReaderError.invalid
      }
      return .text(text)
    case 4:
      let remainingBytes = bytes.count - offset
      guard argument <= UInt64(remainingBytes) else { throw RelayCBORReaderError.truncated }
      guard UInt64(nodeCount) + argument <= UInt64(FirehoseFrameLimits.maximumAggregateNodes) else {
        throw RelayCBORReaderError.invalid
      }
      var values: [RelayCBORValue] = []
      values.reserveCapacity(min(Int(argument), 128))
      for _ in 0 ..< argument { values.append(try read(depth: depth + 1)) }
      return .array(values)
    case 5:
      guard argument <= 128 else { throw RelayCBORReaderError.invalid }
      let remainingBytes = bytes.count - offset
      guard argument * 2 <= UInt64(remainingBytes) else { throw RelayCBORReaderError.truncated }
      guard UInt64(nodeCount) + argument * 2 <= UInt64(FirehoseFrameLimits.maximumAggregateNodes) else {
        throw RelayCBORReaderError.invalid
      }
      var entries: [(String, RelayCBORValue)] = []
      entries.reserveCapacity(Int(argument))
      var previous: Data?
      for _ in 0 ..< argument {
        guard case let .text(key) = try read(depth: depth + 1) else {
          throw RelayCBORReaderError.invalid
        }
        let keyBytes = Data(key.utf8)
        if let previous {
          guard previous.count < keyBytes.count
                  || (previous.count == keyBytes.count
                    && previous.lexicographicallyPrecedes(keyBytes)) else {
            throw RelayCBORReaderError.nonCanonical
          }
        }
        previous = keyBytes
        entries.append((key, try read(depth: depth + 1)))
      }
      return .map(.init(entries))
    case 6:
      guard argument == 42 else { throw RelayCBORReaderError.invalid }
      guard case let .bytes(linkBytes) = try read(depth: depth + 1),
            linkBytes.count == 37,
            linkBytes.first == 0 else {
        throw RelayCBORReaderError.invalidCID
      }
      do {
        return .cidLink(try CID(bytes: Data(linkBytes.dropFirst())))
      } catch {
        throw RelayCBORReaderError.invalidCID
      }
    case 7:
      switch argument {
      case 20: return .boolean(false)
      case 21: return .boolean(true)
      case 22: return .null
      default: throw RelayCBORReaderError.invalid
      }
    default: throw RelayCBORReaderError.invalid
    }
  }

  private mutating func readArgument(_ initial: UInt8) throws -> UInt64 {
    switch initial & 0x1f {
    case 0 ... 23: return UInt64(initial & 0x1f)
    case 24:
      let value = try fixed(1)
      guard value >= 24 else { throw RelayCBORReaderError.nonCanonical }
      return value
    case 25:
      let value = try fixed(2)
      guard value > UInt8.max else { throw RelayCBORReaderError.nonCanonical }
      return value
    case 26:
      let value = try fixed(4)
      guard value > UInt16.max else { throw RelayCBORReaderError.nonCanonical }
      return value
    case 27:
      let value = try fixed(8)
      guard value > UInt32.max else { throw RelayCBORReaderError.nonCanonical }
      return value
    default: throw RelayCBORReaderError.invalid
    }
  }

  private mutating func fixed(_ count: Int) throws -> UInt64 {
    guard count <= bytes.count - offset else { throw RelayCBORReaderError.truncated }
    var result: UInt64 = 0
    for byte in bytes[offset ..< offset + count] {
      result = (result << 8) | UInt64(byte)
    }
    offset += count
    return result
  }

  private mutating func payload(_ length: UInt64) throws -> [UInt8] {
    guard length <= UInt64(bytes.count - offset) else {
      throw RelayCBORReaderError.truncated
    }
    let result = Array(bytes[offset ..< offset + Int(length)])
    offset += Int(length)
    return result
  }

  private mutating func readByte() -> UInt8? {
    guard offset < bytes.count else { return nil }
    defer { offset += 1 }
    return bytes[offset]
  }
}
