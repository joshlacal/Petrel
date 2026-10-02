import Foundation
@testable import Petrel
import Testing

// Equivalence tests for the cbor-layout changes: in-place OrderedCBORMap
// building, the union-variant map helper, the exact-metatype fast paths in
// `ATProtocolValueContainer.containerFromCBORValue`, memberwise generated `==`,
// and the compact `ATProtocolValueContainer` layout. Each test compares the new
// code with a verbatim copy of what it replaced, so a divergence fails here
// rather than only in a cross-build corpus diff.

// MARK: - Legacy references (verbatim copies of the replaced code)

/// The cast chain `containerFromCBORValue` used before the fast paths, with its
/// recursion pointed at itself so nested values also take the legacy route.
private func legacyContainerFromCBORValue(_ value: Any) -> ATProtocolValueContainer {
    switch value {
    case let container as ATProtocolValueContainer:
        return container
    case let map as OrderedCBORMap:
        var dict = [String: ATProtocolValueContainer]()
        dict.reserveCapacity(map.entries.count)
        for entry in map.entries {
            dict[entry.key] = legacyContainerFromCBORValue(entry.value)
        }
        return .object(dict)
    case let dictionary as [String: Any]:
        var dict = [String: ATProtocolValueContainer]()
        dict.reserveCapacity(dictionary.count)
        for (key, val) in dictionary {
            dict[key] = legacyContainerFromCBORValue(val)
        }
        return .object(dict)
    case let array as [Any]:
        return .array(array.map(legacyContainerFromCBORValue))
    case let string as String:
        return .string(string)
    case let int as Int:
        return .number(int)
    case let int64 as Int64:
        return .number(Int(int64))
    case let int32 as Int32:
        return .number(Int(int32))
    case let int16 as Int16:
        return .number(Int(int16))
    case let int8 as Int8:
        return .number(Int(int8))
    case let uint as UInt:
        return uint <= UInt(Int.max) ? .number(Int(uint)) : .string(String(uint))
    case let uint64 as UInt64:
        return uint64 <= UInt64(Int.max) ? .number(Int(uint64)) : .string(String(uint64))
    case let uint32 as UInt32:
        return .number(Int(uint32))
    case let uint16 as UInt16:
        return .number(Int(uint16))
    case let uint8 as UInt8:
        return .number(Int(uint8))
    case let bool as Bool:
        return .bool(bool)
    case is NSNull:
        return .null
    case let link as ATProtoLink:
        return .link(link)
    case let cid as CID:
        return .link(ATProtoLink(cid: cid))
    case let bytes as Bytes:
        return .bytes(bytes)
    case let data as Data:
        return .bytes(Bytes(data: data))
    case let cidValue as CIDAsLink:
        switch cidValue.representation {
        case .link:
            return .link(ATProtoLink(cid: cidValue.cid))
        case .string:
            return .string(cidValue.cid.string)
        }
    case let uri as ATProtocolURI:
        return .string(uri.uriString())
    case let val as any DAGCBOREncodable:
        if let innerCBOR = try? val.toCBORValue() {
            return legacyContainerFromCBORValue(innerCBOR)
        }
        return .null
    default:
        return .null
    }
}

/// The map the generated union `toCBORValue()` built before `unionVariant`.
private func legacyUnionVariantMap(typeIdentifier: String, payload: Any) -> OrderedCBORMap {
    var map = OrderedCBORMap()
    map = map.adding(key: "$type", value: typeIdentifier)
    if let orderedMap = payload as? OrderedCBORMap {
        for (key, value) in orderedMap.entries where key != "$type" {
            map = map.adding(key: key, value: value)
        }
    } else if let dict = payload as? [String: Any] {
        for (key, value) in dict where key != "$type" {
            map = map.adding(key: key, value: value)
        }
    }
    return map
}

/// Field-by-field equality through `Mirror`: the semantics the old generated
/// `==` had (it compared every stored property with that property's `!=`).
/// Returns nil when a stored property is not Equatable.
private func mirrorFieldwiseEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    let left = Mirror(reflecting: lhs).children.map(\.value)
    let right = Mirror(reflecting: rhs).children.map(\.value)
    guard left.count == right.count else { return false }
    for (l, r) in zip(left, right) {
        guard let equal = fieldEqual(l, r) else { return nil }
        if !equal { return false }
    }
    return true
}

/// `l == r` for two stored-property values boxed in `Any`, unwrapping Optionals
/// explicitly (a dynamic cast of `Optional.none` to `any Equatable` fails).
private func fieldEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    let leftMirror = Mirror(reflecting: lhs)
    let rightMirror = Mirror(reflecting: rhs)
    if leftMirror.displayStyle == .optional || rightMirror.displayStyle == .optional {
        let left: Any? = leftMirror.displayStyle == .optional ? leftMirror.children.first?.value : .some(lhs)
        let right: Any? = rightMirror.displayStyle == .optional ? rightMirror.children.first?.value : .some(rhs)
        switch (left, right) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (left?, right?): return fieldEqual(left, right)
        }
    }
    guard let equatable = lhs as? any Equatable else { return nil }
    return openedEqual(equatable, rhs)
}

private func openedEqual<T: Equatable>(_ lhs: T, _ rhs: Any) -> Bool {
    guard let rhs = rhs as? T else { return false }
    return lhs == rhs
}

private func sortedJSON(_ value: ATProtocolValueContainer) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

private let sampleCID = "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm"

// MARK: - Fixture helpers

private func decodeTimeline(_ data: Data) throws -> [AppBskyFeedDefs.FeedViewPost] {
    try JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self, from: data).feed
}

private func timelineData() -> Data { Data(CBORLayoutFixtures.timelineJSON.utf8) }

private func leafPaths(_ value: Any, _ path: [Any], into paths: inout [[Any]]) {
    if let dict = value as? [String: Any] {
        for key in dict.keys.sorted() { leafPaths(dict[key]!, path + [key], into: &paths) }
    } else if let array = value as? [Any] {
        for (index, element) in array.enumerated() { leafPaths(element, path + [index], into: &paths) }
    } else {
        paths.append(path)
    }
}

private func mutatedLeaf(_ value: Any) -> Any? {
    if let string = value as? String { return string + "x" }
    if let number = value as? NSNumber {
        if String(cString: number.objCType) == "c" { return !number.boolValue }
        return number.int64Value + 1
    }
    return nil
}

private func replacingLeaf(_ value: Any, at path: ArraySlice<Any>) -> Any? {
    guard let head = path.first else { return mutatedLeaf(value) }
    if var dict = value as? [String: Any], let key = head as? String, let child = dict[key] {
        guard let replaced = replacingLeaf(child, at: path.dropFirst()) else { return nil }
        dict[key] = replaced
        return dict
    }
    if var array = value as? [Any], let index = head as? Int {
        guard let replaced = replacingLeaf(array[index], at: path.dropFirst()) else { return nil }
        array[index] = replaced
        return array
    }
    return nil
}

// MARK: - Tests

@Suite("cbor-layout equivalence")
struct CBORLayoutEquivalenceTests {
    // MARK: OrderedCBORMap

    @Test("consuming adding keeps value semantics for the receiver")
    func consumingAddingKeepsValueSemantics() throws {
        let original = OrderedCBORMap(entries: [(key: "a", value: 1)])
        let extended = original.adding(key: "b", value: "two")
        let again = original.adding(key: "c", value: true)
        #expect(original.entries.map(\.key) == ["a"])
        #expect(extended.entries.map(\.key) == ["a", "b"])
        #expect(again.entries.map(\.key) == ["a", "c"])

        var chained = OrderedCBORMap()
        var appended = OrderedCBORMap(minimumCapacity: 40)
        for index in 0 ..< 40 {
            chained = chained.adding(key: "k\(index % 7)", value: index)
            appended.append(key: "k\(index % 7)", value: index)
        }
        #expect(chained.entries.map(\.key) == appended.entries.map(\.key))
        #expect(chained.entries.map { $0.value as? Int } == appended.entries.map { $0.value as? Int })
        #expect(try chained.encodedDAGCBOR() == appended.encodedDAGCBOR())
    }

    @Test("unionVariant builds exactly the legacy adding sequence for every payload shape")
    func unionVariantMatchesLegacy() throws {
        let cid = try CID.parse(sampleCID)
        let nested = OrderedCBORMap(entries: [(key: "x", value: 1)])
        let payloads: [Any] = [
            OrderedCBORMap(entries: [(key: "$type", value: "a.b#c"), (key: "text", value: "hi"), (key: "n", value: 3)]),
            OrderedCBORMap(entries: [(key: "text", value: "hi"), (key: "$type", value: "a.b#c"), (key: "link", value: CIDAsLink(cid: cid, representation: .link))]),
            OrderedCBORMap(entries: [(key: "$type", value: "one"), (key: "$type", value: "two"), (key: "k", value: nested)]),
            OrderedCBORMap(entries: [(key: "dup", value: 1), (key: "dup", value: 2)]),
            OrderedCBORMap(),
            ["$type": "a.b#c", "text": "hi", "n": 3, "list": [1, 2, 3] as [Any]] as [String: Any],
            ["only": "strings", "$type": "x"] as [String: String],
            [String: Any](),
            NSDictionary(dictionary: ["k": "v", "$type": "t"]),
            "not a map",
            42,
            [1, 2, 3] as [Any],
            NSNull(),
        ]
        for payload in payloads {
            let legacy = legacyUnionVariantMap(typeIdentifier: "app.example.union#member", payload: payload)
            let current = OrderedCBORMap.unionVariant(typeIdentifier: "app.example.union#member", payload: payload)
            #expect(current.entries.map(\.key) == legacy.entries.map(\.key), "keys differ for \(payload)")
            #expect(
                current.entries.map { legacyContainerFromCBORValue($0.value) } == legacy.entries.map { legacyContainerFromCBORValue($0.value) },
                "values differ for \(payload)"
            )
            #expect(try current.encodedDAGCBOR() == legacy.encodedDAGCBOR())
        }
    }

    // MARK: containerFromCBORValue

    @Test("exact-metatype fast paths return exactly what the legacy cast chain returns")
    func containerFromCBORValueMatchesLegacyChain() throws {
        let cid = try CID.parse(sampleCID)
        let uri = try ATProtocolURI(uriString: "at://did:plc:abc123/app.bsky.feed.post/3kabc")
        let did = try DID(didString: "did:plc:abc123")
        let post = try JSONDecoder().decode(
            AppBskyFeedPost.self,
            from: Data(#"{"$type":"app.bsky.feed.post","text":"hi","createdAt":"2026-07-15T12:00:00.000Z","langs":["en"]}"#.utf8)
        )
        let optionalString: String? = "wrapped"
        let optionalNone: Int? = nil
        let optionalBool: Bool? = true
        var corpus: [Any] = [
            "", "hello", "ünïcödé 🎉", "nul\u{0}inside",
            0, 1, -1, Int.max, Int.min,
            true, false,
            Int8(-3), Int16(300), Int32(-70000), Int64.max, Int64.min,
            UInt(5), UInt.max, UInt64(7), UInt64.max, UInt32.max, UInt16(9), UInt8(255),
            1.5 as Double, Float(2), Character("c"), Date(timeIntervalSince1970: 0),
            NSNumber(value: true), NSNumber(value: false), NSNumber(value: 1), NSNumber(value: 0),
            NSNumber(value: 2.5), NSNumber(value: UInt64.max), NSNumber(value: Int8(-1)),
            NSString(string: "ns"), NSArray(array: ["a", 1, true]), NSDictionary(dictionary: ["k": "v", "n": 2]),
            NSNull(),
            optionalString as Any, optionalNone as Any, optionalBool as Any,
            AnyHashable("h"), AnyHashable(7), AnyHashable(true),
            ["a", 1, true, NSNull(), ["nested", 2] as [Any]] as [Any],
            ["x", "y"], [1, 2, 3], [true, false], [UInt8(1), UInt8(2)], [[1], [2, 3]],
            ["a": 1, "b": "x", "c": [1, "two"] as [Any]] as [String: Any],
            ["k": "v"] as [String: String], ["k": 1] as [String: Int],
            cid,
            CIDAsLink(cid: cid, representation: .link), CIDAsLink(cid: cid, representation: .string),
            ATProtoLink(cid: cid), Bytes(data: Data([1, 2, 3])), Data([4, 5, 6]),
            uri, did,
            ATProtocolValueContainer.string("container"),
            ATProtocolValueContainer.object(["k": .number(1), "l": .array([.bool(true), .null])]),
            ATProtocolValueContainer.knownType(post),
            post,
        ]
        corpus.append(OrderedCBORMap(entries: corpus.enumerated().map { (key: "k\($0.offset)", value: $0.element) }))
        corpus.append(corpus.map { $0 } as [Any])
        corpus.append(try post.toCBORValue())
        for item in try decodeTimeline(timelineData()) {
            corpus.append(try item.toCBORValue())
            corpus.append(try item.post.toCBORValue())
            corpus.append(try item.post.record.toCBORValue())
            if case let .knownType(value) = item.post.record {
                corpus.append(try value.toCBORValue())
            }
        }

        for value in corpus {
            let legacy = legacyContainerFromCBORValue(value)
            let current = ATProtocolValueContainer.containerFromCBORValue(value)
            #expect(current == legacy, "containerFromCBORValue diverged for \(type(of: value)): \(value)")
            if case .knownType = legacy { continue }
            #expect(try sortedJSON(current) == sortedJSON(legacy), "JSON differs for \(type(of: value))")
        }
    }

    @Test("Bool and Int stored as Any never cross-cast, so fast-path order is irrelevant")
    func nativeScalarsDoNotCrossCast() {
        let boolValue: Any = true
        let intValue: Any = 1
        let stringValue: Any = "1"
        #expect((boolValue as? Int) == nil)
        #expect((intValue as? Bool) == nil)
        #expect((intValue as? String) == nil)
        #expect((stringValue as? [Any]) == nil)
        #expect((stringValue as? [String: Any]) == nil)
        #expect(ATProtocolValueContainer.containerFromCBORValue(boolValue) == .bool(true))
        #expect(ATProtocolValueContainer.containerFromCBORValue(intValue) == .number(1))
    }

    // MARK: Generated ==

    @Test("memberwise == equals the old field-by-field comparison on a decoded timeline and single-leaf mutations")
    func memberwiseEqualityMatchesFieldwiseReference() throws {
        let data = timelineData()
        let first = try decodeTimeline(data)
        let second = try decodeTimeline(data)
        #expect(first.count == 4)

        var compared = 0
        func check(_ lhs: AppBskyFeedDefs.FeedViewPost, _ rhs: AppBskyFeedDefs.FeedViewPost) {
            let expected = mirrorFieldwiseEqual(lhs, rhs)
            #expect(expected != nil)
            #expect((lhs == rhs) == expected)
            #expect(lhs.isEqual(to: rhs) == (lhs == rhs))
            #expect((lhs.post == rhs.post) == mirrorFieldwiseEqual(lhs.post, rhs.post))
            #expect((lhs.post.author == rhs.post.author) == mirrorFieldwiseEqual(lhs.post.author, rhs.post.author))
            if lhs == rhs {
                #expect(lhs.hashValue == rhs.hashValue)
            }
            compared += 1
        }

        for lhs in first {
            for rhs in second {
                check(lhs, rhs)
            }
        }

        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try #require(root["feed"] as? [Any])
        var mutations = 0
        for (index, item) in items.enumerated() {
            var paths: [[Any]] = []
            leafPaths(item, [], into: &paths)
            for path in paths {
                guard let changed = replacingLeaf(item, at: path[...]) else { continue }
                let doc = try JSONSerialization.data(withJSONObject: ["feed": [changed]])
                guard let decoded = try? decodeTimeline(doc), decoded.count == 1 else { continue }
                check(first[index], decoded[0])
                mutations += 1
            }
        }
        #expect(mutations > 200)
        #expect(compared > mutations)
    }

    @Test("union .unexpected equality is ATProtocolValueContainer equality")
    func unionUnexpectedEquality() throws {
        let json = #"{"$type":"app.example.unknown#thing","a":1,"b":["x",{"c":true}]}"#
        let lhs = try JSONDecoder().decode(AppBskyFeedDefs.PostViewEmbedUnion.self, from: Data(json.utf8))
        let rhs = try JSONDecoder().decode(AppBskyFeedDefs.PostViewEmbedUnion.self, from: Data(json.utf8))
        let other = try JSONDecoder().decode(
            AppBskyFeedDefs.PostViewEmbedUnion.self,
            from: Data(#"{"$type":"app.example.unknown#thing","a":2}"#.utf8)
        )
        guard case let .unexpected(lhsContainer) = lhs, case let .unexpected(otherContainer) = other else {
            Issue.record("expected .unexpected union members")
            return
        }
        #expect(lhs == rhs)
        #expect(lhs != other)
        #expect((lhs == other) == lhsContainer.isEqual(to: otherContainer))
        #expect(lhs.isEqual(to: rhs))
    }

    // MARK: ATProtocolValueContainer layout

    @Test("compact ATProtocolValueContainer layout fits an existential inline buffer")
    func compactContainerLayout() throws {
        // Scalar cases are stored inline; knownType, link and unknownType are boxed.
        #expect(MemoryLayout<ATProtocolValueContainer>.size <= 3 * MemoryLayout<Int>.size)
        #expect(MemoryLayout<ATProtocolValueContainer>.alignment <= MemoryLayout<Int>.alignment)

        let cid = try CID.parse(sampleCID)
        let post = try JSONDecoder().decode(
            AppBskyFeedPost.self,
            from: Data(#"{"$type":"app.bsky.feed.post","text":"hi","createdAt":"2026-07-15T12:00:00.000Z"}"#.utf8)
        )
        let values: [ATProtocolValueContainer] = [
            .knownType(post), .string("s"), .number(-7), .bigNumber("18446744073709551615"),
            .object(["k": .link(ATProtoLink(cid: cid))]), .array([.bytes(Bytes(data: Data([9]))), .null]),
            .bool(false), .null, .link(ATProtoLink(cid: cid)), .bytes(Bytes(data: Data([1, 2]))),
            .unknownType("x.y#z", .unknownType("inner", .object(["n": .number(1)]))),
            .decodeError("bad"),
        ]
        for (index, value) in values.enumerated() {
            let copy = value
            #expect(copy == value)
            for (otherIndex, other) in values.enumerated() where otherIndex != index {
                #expect(value != other)
            }
            if case .decodeError = value { continue }
            let encoded = try JSONEncoder().encode(value)
            #expect(!encoded.isEmpty)
        }
    }
}
