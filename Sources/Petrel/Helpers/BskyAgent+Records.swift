import Foundation

// MARK: - Generic XRPC with per-call options

public extension BskyAgent {
    /// Calls any lexicon query with options that apply to this call only.
    ///
    /// Use this when a call needs a proxy target or a labeler list different
    /// from the client's defaults. The generated method for the same lexicon
    /// stays the simpler choice otherwise.
    ///
    /// ```swift
    /// let convos = try await client.bsky.query(
    ///     "chat.bsky.convo.listConvos",
    ///     parameters: ChatBskyConvoListConvos.Parameters(limit: 20),
    ///     as: ChatBskyConvoListConvos.Output.self,
    ///     options: BskyCallOptions(proxy: .bskyChat)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - nsid: The lexicon method, for example `app.bsky.feed.getTimeline`.
    ///   - parameters: The generated `Parameters` value of the method, if it takes any.
    ///   - output: The generated `Output` type of the method.
    ///   - options: Proxy, labelers and headers for this call.
    func query<Output: Decodable>(
        _ nsid: String,
        parameters: (any Parametrizable)? = nil,
        as output: Output.Type = Output.self,
        options: BskyCallOptions = BskyCallOptions()
    ) async throws -> Output {
        let response = try await xrpcQuery(nsid, query: parameters?.asQueryItems() ?? [], options: options)
        return try response.decode(output, nsid: nsid)
    }

    /// Calls any lexicon procedure with options that apply to this call only.
    ///
    /// - Parameters:
    ///   - nsid: The lexicon method, for example `chat.bsky.convo.sendMessage`.
    ///   - input: The generated `Input` value of the method.
    ///   - output: The generated `Output` type of the method.
    ///   - options: Proxy, labelers and headers for this call.
    func procedure<Input: Encodable, Output: Decodable>(
        _ nsid: String,
        input: Input,
        as output: Output.Type = Output.self,
        options: BskyCallOptions = BskyCallOptions()
    ) async throws -> Output {
        let response = try await xrpc("POST", nsid, body: Self.encodeBody(input, nsid: nsid), options: options)
        return try response.decode(output, nsid: nsid)
    }

    /// Calls a lexicon procedure that returns no body, with options that apply to this call only.
    func procedure<Input: Encodable>(
        _ nsid: String,
        input: Input,
        options: BskyCallOptions = BskyCallOptions()
    ) async throws {
        _ = try await xrpc("POST", nsid, body: Self.encodeBody(input, nsid: nsid), options: options)
    }

    private static func encodeBody<Input: Encodable>(_ input: Input, nsid: String) throws -> Data {
        do {
            return try JSONEncoder().encode(input)
        } catch {
            throw BskyAgentError.invalidInput("The input for \(nsid) could not be encoded: \(error)")
        }
    }
}

// MARK: - Records

public extension BskyAgent {
    /// Creates a record in the signed-in account's repository.
    ///
    /// - Parameters:
    ///   - record: The record. Generated record types carry their own `$type`.
    ///   - collection: The collection NSID; defaults to the record's `$type`.
    ///   - rkey: The record key, or `nil` to let the PDS assign a TID.
    ///   - validate: Passed through to `com.atproto.repo.createRecord`.
    ///   - swapCommit: Only write if the repository head is still this commit.
    /// - Returns: The URI and CID of the new record.
    @discardableResult
    func createRecord<Record: Encodable>(
        _ record: Record,
        collection: String? = nil,
        rkey: String? = nil,
        validate: Bool? = nil,
        swapCommit: CID? = nil
    ) async throws -> ComAtprotoRepoStrongRef {
        let nsid = "com.atproto.repo.createRecord"
        let (json, resolvedCollection) = try Self.recordJSON(record, collection: collection)
        let repo = try await did().didString()
        var body: [String: BskyJSON] = [
            "repo": .string(repo),
            "collection": .string(resolvedCollection),
            "record": json,
        ]
        if let rkey { body["rkey"] = try .string(Self.validatedRecordKey(rkey)) }
        if let validate { body["validate"] = .bool(validate) }
        if let swapCommit { body["swapCommit"] = .string(swapCommit.string) }
        return try await xrpcProcedure(nsid, body: .object(body)).decode(ComAtprotoRepoStrongRef.self, nsid: nsid)
    }

    /// Creates or replaces a record at a known key in the signed-in account's repository.
    ///
    /// - Parameters:
    ///   - record: The record.
    ///   - collection: The collection NSID; defaults to the record's `$type`.
    ///   - rkey: The record key.
    ///   - validate: Passed through to `com.atproto.repo.putRecord`.
    ///   - swapRecord: Compare-and-swap guard on the record's current CID.
    /// - Returns: The URI and CID of the stored record.
    @discardableResult
    func putRecord<Record: Encodable>(
        _ record: Record,
        collection: String? = nil,
        rkey: String,
        validate: Bool? = nil,
        swapRecord: RecordSwap = .any
    ) async throws -> ComAtprotoRepoStrongRef {
        let (json, resolvedCollection) = try Self.recordJSON(record, collection: collection)
        return try await putRecordJSON(
            json,
            collection: resolvedCollection,
            rkey: rkey,
            validate: validate,
            swapRecord: swapRecord
        )
    }

    /// Deletes a record of the signed-in account.
    ///
    /// Deleting a record that does not exist succeeds, as the lexicon specifies.
    ///
    /// - Parameter uri: The `at://` URI of the record. Its authority names the repository.
    func deleteRecord(_ uri: ATProtocolURI) async throws {
        _ = try await did() // Deleting requires a session even though the URI names the repository.
        guard let collection = uri.collection, let rkey = uri.recordKey else {
            throw BskyAgentError.invalidInput("Not a record URI: \(uri.uriString())")
        }
        _ = try await xrpcProcedure("com.atproto.repo.deleteRecord", body: .object([
            "repo": .string(uri.authority),
            "collection": .string(collection),
            "rkey": .string(rkey),
        ]))
    }

    /// Reads one record from any repository, decoded as a generated record type.
    ///
    /// - Parameters:
    ///   - type: The record type, for example `AppBskyFeedPost.self`.
    ///   - uri: The `at://` URI of the record.
    /// - Returns: The record with its CID, or `nil` when it does not exist.
    func getRecord<Record: Decodable>(
        _ type: Record.Type,
        at uri: ATProtocolURI
    ) async throws -> (value: Record, ref: ComAtprotoRepoStrongRef)? {
        guard let collection = uri.collection, let rkey = uri.recordKey else {
            throw BskyAgentError.invalidInput("Not a record URI: \(uri.uriString())")
        }
        guard let raw = try await getRecordJSON(repo: uri.authority, collection: collection, rkey: rkey) else {
            return nil
        }
        let nsid = "com.atproto.repo.getRecord"
        guard let ref = raw.strongRef else {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Missing or malformed record URI or CID")
        }
        do {
            return try (raw.value.decoded(as: type), ref)
        } catch {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Record is not a valid \(type)")
        }
    }
}

/// The compare-and-swap condition of a record write.
public enum RecordSwap: Sendable, Hashable {
    /// Write regardless of what is stored.
    case any
    /// Write only if no record exists at this key yet.
    case mustNotExist
    /// Write only if the stored record still has this CID.
    case matches(CID)
}

// MARK: - Internals

extension BskyAgent {
    struct RawRecord: Sendable {
        let uri: String
        let cid: String?
        let value: BskyJSON

        /// The record's URI and CID as a strong reference, when both are well-formed.
        var strongRef: ComAtprotoRepoStrongRef? {
            guard let cid else { return nil }
            return try? BskyJSON.object(["uri": .string(uri), "cid": .string(cid)])
                .decoded(as: ComAtprotoRepoStrongRef.self)
        }
    }

    /// Reads a record as raw JSON; `nil` when the repository has no such record.
    func getRecordJSON(repo: String, collection: String, rkey: String) async throws -> RawRecord? {
        let nsid = "com.atproto.repo.getRecord"
        let response: BskyXRPCResponse
        do {
            response = try await xrpcQuery(nsid, query: [
                URLQueryItem(name: "repo", value: repo),
                URLQueryItem(name: "collection", value: collection),
                URLQueryItem(name: "rkey", value: rkey),
            ])
        } catch let error as BskyAgentError where error.xrpcErrorName == "RecordNotFound" {
            return nil
        }
        let json = try response.json(nsid: nsid)
        guard let uri = json["uri"]?.stringValue, let value = json["value"], value.objectValue != nil else {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Missing uri or value")
        }
        return RawRecord(uri: uri, cid: json["cid"]?.stringValue, value: value)
    }

    /// Rewrites the record at `rkey` in the signed-in repository from what is
    /// stored there, on the condition that nobody changed it in between.
    ///
    /// `transform` receives the stored record (`nil` when there is none) and
    /// returns the record to write. When another writer got there first the
    /// record is read again and `transform` runs again, up to six times.
    @discardableResult
    func upsertRecordJSON(
        collection: String,
        rkey: String,
        _ transform: (RawRecord?) async throws -> BskyJSON
    ) async throws -> ComAtprotoRepoStrongRef {
        let repo = try await did().didString()
        let maxAttempts = 6

        for _ in 0 ..< maxAttempts {
            let existing = try await getRecordJSON(repo: repo, collection: collection, rkey: rkey)
            let record = try await transform(existing)

            let swap: RecordSwap
            if let existing {
                guard let ref = existing.strongRef else {
                    throw BskyAgentError.invalidResponse(
                        nsid: "com.atproto.repo.getRecord",
                        reason: "Missing or malformed record CID"
                    )
                }
                swap = .matches(ref.cid)
            } else {
                swap = .mustNotExist
            }

            do {
                return try await putRecordJSON(record, collection: collection, rkey: rkey, swapRecord: swap)
            } catch let error as BskyAgentError where error.xrpcErrorName == "InvalidSwap" {
                continue
            }
        }
        throw BskyAgentError.swapRetriesExhausted(attempts: maxAttempts)
    }

    @discardableResult
    func putRecordJSON(
        _ record: BskyJSON,
        collection: String,
        rkey: String,
        validate: Bool? = nil,
        swapRecord: RecordSwap
    ) async throws -> ComAtprotoRepoStrongRef {
        let nsid = "com.atproto.repo.putRecord"
        let repo = try await did().didString()
        var body: [String: BskyJSON] = try [
            "repo": .string(repo),
            "collection": .string(collection),
            "rkey": .string(Self.validatedRecordKey(rkey)),
            "record": record,
        ]
        if let validate { body["validate"] = .bool(validate) }
        switch swapRecord {
        case .any: break
        case .mustNotExist: body["swapRecord"] = .null
        case let .matches(cid): body["swapRecord"] = .string(cid.string)
        }
        return try await xrpcProcedure(nsid, body: .object(body)).decode(ComAtprotoRepoStrongRef.self, nsid: nsid)
    }

    /// Encodes a record and settles its collection: the explicit one, else the record's `$type`.
    static func recordJSON<Record: Encodable>(
        _ record: Record,
        collection: String?
    ) throws -> (json: BskyJSON, collection: String) {
        var json: BskyJSON
        do {
            json = try BskyJSON.encoding(record)
        } catch {
            throw BskyAgentError.invalidInput("The record could not be encoded: \(error)")
        }
        guard json.objectValue != nil else {
            throw BskyAgentError.invalidInput("A record must encode to a JSON object")
        }
        guard let resolved = collection ?? json.typeIdentifier else {
            throw BskyAgentError.invalidInput("The record has no $type; pass the collection explicitly")
        }
        guard NSID.isValidNSID(resolved) else {
            throw BskyAgentError.invalidInput("Not a valid collection NSID: \(resolved)")
        }
        if json.typeIdentifier == nil {
            json["$type"] = .string(resolved)
        }
        return (json, resolved)
    }

    static func validatedRecordKey(_ rkey: String) throws -> String {
        guard RecordKey.isValidRecordKey(rkey) else {
            throw BskyAgentError.invalidInput("Not a valid record key: \(rkey)")
        }
        return rkey
    }

    /// Splits a record URI of an expected collection into repository and record key.
    static func recordLocation(
        _ uri: ATProtocolURI,
        expecting collection: String
    ) throws -> (repo: String, rkey: String) {
        guard uri.collection == collection, let rkey = uri.recordKey else {
            throw BskyAgentError.invalidInput("Expected a \(collection) record URI, got \(uri.uriString())")
        }
        return (uri.authority, rkey)
    }

    /// The current time as a record timestamp.
    static func now() -> ATProtocolDate {
        ATProtocolDate(date: Date())
    }
}
