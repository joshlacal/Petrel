import Foundation

// lexicon: 1, id: chat.bsky.moderation.updateActorAccess

public enum ChatBskyModerationUpdateActorAccess {
    public static let typeIdentifier = "chat.bsky.moderation.updateActorAccess"
    public struct Input: ATProtocolCodable {
        public let actor: DID
        public let allowAccess: Bool
        public let ref: String?

        // Standard public initializer
        public init(actor: DID, allowAccess: Bool, ref: String? = nil) {
            self.actor = actor
            self.allowAccess = allowAccess
            self.ref = ref
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            actor = try container.decode(DID.self, forKey: .actor)

            allowAccess = try container.decode(Bool.self, forKey: .allowAccess)

            ref = try container.decodeIfPresent(String.self, forKey: .ref)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(actor, forKey: .actor)

            try container.encode(allowAccess, forKey: .allowAccess)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(ref, forKey: .ref)
        }

        private enum CodingKeys: String, CodingKey {
            case actor
            case allowAccess
            case ref
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let actorValue = try (actor as? DAGCBOREncodable)?.toCBORValue() ?? actor
            map = map.adding(key: "actor", value: actorValue)

            let allowAccessValue = try (allowAccess as? DAGCBOREncodable)?.toCBORValue() ?? allowAccess
            map = map.adding(key: "allowAccess", value: allowAccessValue)

            if let value = ref {
                // Encode optional property even if it's an empty array for CBOR

                let refValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "ref", value: refValue)
            }

            return map
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Moderation {
    ///
    func updateActorAccess(
        input: ChatBskyModerationUpdateActorAccess.Input

    ) async throws -> Int {
        let endpoint = "chat.bsky.moderation.updateActorAccess"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
