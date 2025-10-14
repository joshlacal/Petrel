import Foundation

// lexicon: 1, id: com.atproto.identity.signPlcOperation

public enum ComAtprotoIdentitySignPlcOperation {
    public static let typeIdentifier = "com.atproto.identity.signPlcOperation"
    public struct Input: ATProtocolCodable {
        public let token: String?
        public let rotationKeys: [String]?
        public let alsoKnownAs: [String]?
        public let verificationMethods: ATProtocolValueContainer?
        public let services: ATProtocolValueContainer?

        // Standard public initializer
        public init(token: String? = nil, rotationKeys: [String]? = nil, alsoKnownAs: [String]? = nil, verificationMethods: ATProtocolValueContainer? = nil, services: ATProtocolValueContainer? = nil) {
            self.token = token
            self.rotationKeys = rotationKeys
            self.alsoKnownAs = alsoKnownAs
            self.verificationMethods = verificationMethods
            self.services = services
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            token = try container.decodeIfPresent(String.self, forKey: .token)

            rotationKeys = try container.decodeIfPresent([String].self, forKey: .rotationKeys)

            alsoKnownAs = try container.decodeIfPresent([String].self, forKey: .alsoKnownAs)

            verificationMethods = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .verificationMethods)

            services = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .services)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(token, forKey: .token)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rotationKeys, forKey: .rotationKeys)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(alsoKnownAs, forKey: .alsoKnownAs)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verificationMethods, forKey: .verificationMethods)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(services, forKey: .services)
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case rotationKeys
            case alsoKnownAs
            case verificationMethods
            case services
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = token {
                // Encode optional property even if it's an empty array for CBOR
                let tokenValue = try value.toCBORValue()
                map = map.adding(key: "token", value: tokenValue)
            }

            if let value = rotationKeys {
                // Encode optional property even if it's an empty array for CBOR
                let rotationKeysValue = try value.toCBORValue()
                map = map.adding(key: "rotationKeys", value: rotationKeysValue)
            }

            if let value = alsoKnownAs {
                // Encode optional property even if it's an empty array for CBOR
                let alsoKnownAsValue = try value.toCBORValue()
                map = map.adding(key: "alsoKnownAs", value: alsoKnownAsValue)
            }

            if let value = verificationMethods {
                // Encode optional property even if it's an empty array for CBOR
                let verificationMethodsValue = try value.toCBORValue()
                map = map.adding(key: "verificationMethods", value: verificationMethodsValue)
            }

            if let value = services {
                // Encode optional property even if it's an empty array for CBOR
                let servicesValue = try value.toCBORValue()
                map = map.adding(key: "services", value: servicesValue)
            }

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let operation: ATProtocolValueContainer

        // Standard public initializer
        public init(
            operation: ATProtocolValueContainer

        ) {
            self.operation = operation
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            operation = try container.decode(ATProtocolValueContainer.self, forKey: .operation)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(operation, forKey: .operation)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let operationValue = try operation.toCBORValue()
            map = map.adding(key: "operation", value: operationValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case operation
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - signPlcOperation

    /// Signs a PLC operation to update some value(s) in the requesting DID's document.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func signPlcOperation(
        input: ComAtprotoIdentitySignPlcOperation.Input

    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?) {
        let endpoint = "com.atproto.identity.signPlcOperation"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.identity.signPlcOperation")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoIdentitySignPlcOperation.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.identity.signPlcOperation: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
