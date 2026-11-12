import Foundation
import Petrel
import PetrelRepo

/// How strictly ``RelayFrameDecoder`` validates a frame.
public enum RelayFrameDecodingMode: Sendable, Equatable {
  /// Consumer behaviour required by the event-stream and sync specifications: unknown header
  /// and payload fields are ignored, `#account` status is an open set, the deprecated
  /// `tooBig` / `rebase` / `blobs` commit fields are ignored, and `prev` is optional on
  /// update and delete operations.
  case lenient
  /// Producer conformance checking for relay captures: exact key sets, closed account
  /// statuses, `tooBig` and `rebase` must be false, and sync-1.1 operation shapes.
  case strict
}

/// A frame the consumer skipped instead of failing on.
public struct EventStreamIgnoredFrame: Sendable, Equatable {
  /// Why a frame was skipped.
  public enum Reason: Sendable, Equatable {
    /// The header `op` is neither `1` nor `-1`.
    case unknownOperation
    /// The header `t` names a message type this consumer does not know, including the
    /// deprecated `#handle`, `#migrate` and `#tombstone`.
    case unknownType
    /// The frame was well-formed CBOR with a known type, but the payload did not match the
    /// schema. The associated value describes the failure.
    case undecodablePayload(String)
  }

  /// The header `op` value.
  public let operation: Int64
  /// The header `t` value, when present.
  public let type: String?
  /// The payload `seq`, when the payload carries a valid one. The cursor still advances past
  /// ignored frames.
  public let sequence: Int64?
  /// Why the frame was skipped.
  public let reason: Reason

  /// Creates a description of a skipped frame.
  public init(operation: Int64, type: String?, sequence: Int64?, reason: Reason) {
    self.operation = operation
    self.type = type
    self.sequence = sequence
    self.reason = reason
  }
}

/// The result of decoding one `com.atproto.sync.subscribeRepos` frame.
public enum RelayFrame: Sendable, Equatable {
  /// A message, info or error frame this decoder understands.
  case event(RelayEvent)
  /// A frame with an unknown `op` or `t`, which the specification says to ignore.
  case ignored(EventStreamIgnoredFrame)
}

public enum RelayFrameDecoder {
  /// Decodes one frame into a typed event using ``RelayFrameDecodingMode/lenient`` rules.
  ///
  /// A frame with an unknown `op` or `t` throws, because `RelayEvent` cannot represent it.
  /// Stream consumers call ``decodeFrame(_:mode:)`` and skip ``RelayFrame/ignored(_:)``.
  public static func decode(_ frame: Data) throws -> RelayEvent {
    try decode(frame, mode: .lenient)
  }

  /// Decodes one frame into a typed event.
  ///
  /// A frame with an unknown `op` throws ``RelayVerifierError/invalidFrameHeader`` and one with
  /// an unknown `t` throws ``RelayVerifierError/unknownEventKind``.
  public static func decode(_ frame: Data, mode: RelayFrameDecodingMode) throws -> RelayEvent {
    switch try decodeFrame(frame, mode: mode) {
    case let .event(event):
      return event
    case let .ignored(ignored):
      throw ignored.reason == .unknownOperation
        ? RelayVerifierError.invalidFrameHeader
        : RelayVerifierError.unknownEventKind
    }
  }

  /// Decodes one frame, returning ``RelayFrame/ignored(_:)`` for unknown `op` and `t` values.
  ///
  /// Invalid framing or CBOR (truncation, trailing bytes, non-canonical encoding, a frame above
  /// the 5 MB limit) always throws; the specification treats those as hard errors that drop the
  /// connection. In ``RelayFrameDecodingMode/strict`` mode unknown `op` and `t` throw as well.
  public static func decodeFrame(
    _ frame: Data,
    mode: RelayFrameDecodingMode = .lenient
  ) throws -> RelayFrame {
    let parsed = try parse(frame)
    return try decode(parsed, mode: mode)
  }

  /// Header and payload after the hard framing checks.
  struct ParsedFrame {
    let operation: Int64
    let type: String?
    let headerKeys: Set<String>
    let body: RelayCBORValue

    /// The payload `seq` when it is present and in range.
    var sequence: Int64? {
      guard case let .map(map) = body else { return nil }
      return try? RelayFrameDecoder.sequence(map["seq"])
    }
  }

  static func parse(_ frame: Data) throws -> ParsedFrame {
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
    guard case let .map(headerMap) = header,
          let operation = headerMap.signedInteger("op") else {
      throw RelayVerifierError.invalidFrameHeader
    }
    if operation == 1, headerMap.text("t") == nil {
      throw RelayVerifierError.invalidFrameHeader
    }
    return ParsedFrame(
      operation: operation,
      type: headerMap.text("t"),
      headerKeys: headerMap.keys,
      body: body
    )
  }

  static func decode(_ parsed: ParsedFrame, mode: RelayFrameDecodingMode) throws -> RelayFrame {
    let strict = mode == .strict
    if parsed.operation == -1 {
      if strict, parsed.headerKeys != Set(["op"]) {
        throw RelayVerifierError.invalidFrameHeader
      }
      return .event(.error(try decodeError(parsed.body, strict: strict)))
    }
    guard parsed.operation == 1, let type = parsed.type else {
      if strict { throw RelayVerifierError.invalidFrameHeader }
      return .ignored(.init(
        operation: parsed.operation,
        type: parsed.type,
        sequence: parsed.sequence,
        reason: .unknownOperation
      ))
    }
    if strict, parsed.headerKeys != Set(["op", "t"]) {
      throw RelayVerifierError.invalidFrameHeader
    }
    let body = parsed.body
    switch type {
    case "#identity": return .event(.identity(try decodeIdentity(body, strict: strict)))
    case "#account": return .event(.account(try decodeAccount(body, strict: strict)))
    case "#sync": return .event(.sync(try decodeSync(body, strict: strict)))
    case "#commit": return .event(.commit(try decodeCommit(body, strict: strict)))
    case "#info": return .event(.info(try decodeInfo(body, strict: strict)))
    default:
      if strict { throw RelayVerifierError.unknownEventKind }
      return .ignored(.init(
        operation: parsed.operation,
        type: type,
        sequence: parsed.sequence,
        reason: .unknownType
      ))
    }
  }

  private static func decodeIdentity(_ body: RelayCBORValue, strict: Bool) throws -> RelayIdentityEvent {
    let value = try map(body)
    try value.requireKeys(required: ["seq", "did", "time"], optional: ["handle"], exact: strict)
    return .init(
      seq: try sequence(value["seq"]),
      did: try did(value["did"]),
      time: try requiredText(value["time"]),
      handle: try optionalText(value["handle"])
    )
  }

  private static func decodeAccount(_ body: RelayCBORValue, strict: Bool) throws -> RelayAccountEvent {
    let value = try map(body)
    try value.requireKeys(
      required: ["seq", "did", "time", "active"],
      optional: ["status"],
      exact: strict
    )
    guard case let .boolean(active)? = value["active"] else {
      throw RelayVerifierError.invalidEventBody
    }
    let status = try optionalText(value["status"])
    let allowed = Set([
      "deactivated", "suspended", "takendown", "desynchronized", "throttled", "deleted",
    ])
    // The lexicon declares `status` with open `knownValues`, and an account can be active
    // while carrying a status such as `throttled`; only the strict mode pins both.
    if strict {
      guard active == (status == nil), status.map(allowed.contains) ?? true else {
        throw RelayVerifierError.invalidAccountStatus
      }
    }
    return .init(
      seq: try sequence(value["seq"]),
      did: try did(value["did"]),
      time: try requiredText(value["time"]),
      active: active,
      status: status
    )
  }

  private static func decodeSync(_ body: RelayCBORValue, strict: Bool) throws -> RelaySyncEvent {
    let value = try map(body)
    try value.requireKeys(required: ["seq", "did", "blocks", "rev", "time"], exact: strict)
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

  private static func decodeCommit(_ body: RelayCBORValue, strict: Bool) throws -> RelayCommitEvent {
    let value = try map(body)
    if strict {
      try value.requireKeys(
        required: [
          "seq", "rebase", "tooBig", "repo", "commit", "rev", "since",
          "blocks", "ops", "blobs", "time",
        ],
        optional: ["prevData"],
        exact: true
      )
      guard case .boolean(false)? = value["rebase"],
            case .boolean(false)? = value["tooBig"],
            case let .array(blobValues)? = value["blobs"] else {
        throw RelayVerifierError.invalidEventBody
      }
      for blob in blobValues {
        _ = try cid(blob)
      }
    } else {
      // `rebase`, `tooBig` and `blobs` are deprecated; consumers ignore them.
      try value.requireKeys(
        required: ["seq", "repo", "commit", "rev", "blocks", "ops", "time"],
        exact: false
      )
    }
    guard case let .bytes(blocks)? = value["blocks"],
          case let .array(opValues)? = value["ops"] else {
      throw RelayVerifierError.invalidEventBody
    }
    guard blocks.count <= FirehoseFrameLimits.maximumCommitBlocksBytes else {
      throw RelayVerifierError.commitBlocksTooLarge
    }
    guard opValues.count <= FirehoseFrameLimits.maximumOps else {
      throw RelayVerifierError.tooManyOperations
    }
    let since: String?
    switch value["since"] {
    case nil where !strict: since = nil
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
      ops: try opValues.map { try decodeOperation($0, strict: strict) },
      prevDataCID: prevDataCID,
      time: try requiredText(value["time"])
    )
  }

  private static func decodeOperation(_ encoded: RelayCBORValue, strict: Bool) throws -> RelayRepoOp {
    guard case let .map(value) = encoded else {
      throw RelayVerifierError.invalidRepositoryOperation
    }
    do {
      try value.requireKeys(required: ["action", "path", "cid"], optional: ["prev"], exact: strict)
    } catch {
      throw RelayVerifierError.invalidRepositoryOperation
    }
    guard let actionText = value.text("action"),
          let action = RelayRepoAction(rawValue: actionText),
          let pathText = value.text("path") else {
      throw RelayVerifierError.invalidRepositoryOperation
    }
    if strict {
      _ = try repositoryPath(pathText)
    } else {
      // The lexicon types `path` as a plain string; consumers only need `collection/rkey`.
      let parts = pathText.split(separator: "/", omittingEmptySubsequences: false)
      guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else {
        throw RelayVerifierError.invalidRepositoryOperation
      }
    }
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
    // `prev` was added by sync 1.1 and stays optional in the lexicon; only the strict mode
    // requires it on update and delete.
    switch action {
    case .create where current != nil && previous == nil: break
    case .update where current != nil && (previous != nil || !strict): break
    case .delete where current == nil && (previous != nil || !strict): break
    default: throw RelayVerifierError.invalidRepositoryOperation
    }
    return .init(action: action, path: pathText, cid: current, prev: previous)
  }

  private static func decodeInfo(_ body: RelayCBORValue, strict: Bool) throws -> RelayInfoEvent {
    let value = try map(body)
    try value.requireKeys(required: ["name"], optional: ["message"], exact: strict)
    return .init(
      name: try requiredText(value["name"]),
      message: try optionalText(value["message"])
    )
  }

  private static func decodeError(_ body: RelayCBORValue, strict: Bool) throws -> RelayErrorEvent {
    let value = try map(body)
    try value.requireKeys(required: ["error"], optional: ["message"], exact: strict)
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

  fileprivate static func sequence(_ value: RelayCBORValue?) throws -> Int64 {
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
  case float(Double)
  case null
  case array([RelayCBORValue])
  case map(RelayCBORMap)
  case cidLink(CID)
}

struct RelayCBORMap {
  private let storage: [String: RelayCBORValue]

  /// Builds the map from wire entries.
  ///
  /// - Throws: ``RelayCBORReaderError/invalid`` when two keys collide as Swift `String`s.
  ///   The reader has already checked that the key bytes are distinct and in canonical order,
  ///   but canonically equivalent Unicode spellings (NFC `é` and NFD `e` + U+0301) are
  ///   distinct bytes and the same `String`. A lookup could not tell them apart, so such a map
  ///   is rejected rather than trapping or silently keeping one of the values.
  init(_ entries: [(String, RelayCBORValue)]) throws {
    var storage: [String: RelayCBORValue] = [:]
    storage.reserveCapacity(entries.count)
    for (key, value) in entries {
      guard storage.updateValue(value, forKey: key) == nil else {
        throw RelayCBORReaderError.invalid
      }
    }
    self.storage = storage
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

  /// `exact` additionally rejects keys outside `required` and `optional`; consumers pass
  /// `false` because unknown payload fields must be ignored.
  func requireKeys(required: Set<String>, optional: Set<String> = [], exact: Bool) throws {
    guard required.isSubset(of: keys) else {
      throw RelayVerifierError.invalidEventBody
    }
    if exact {
      guard keys.isSubset(of: required.union(optional)) else {
        throw RelayVerifierError.invalidEventBody
      }
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
    if major == 7 {
      switch initial & 0x1f {
      case 20: return .boolean(false)
      case 21: return .boolean(true)
      case 22: return .null
      case 27:
        // DRISL permits 64-bit floats only; they can appear in fields this decoder skips.
        let value = Double(bitPattern: try fixed(8))
        guard value.isFinite else { throw RelayCBORReaderError.invalid }
        return .float(value)
      default: throw RelayCBORReaderError.invalid
      }
    }
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
      return .map(try .init(entries))
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
