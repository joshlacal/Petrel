import Foundation
internal import ZippyJSON

// lexicon: 1, id: com.atproto.identity.getRecommendedDidCredentials

public enum ComAtprotoIdentityGetRecommendedDidCredentials {
    public static let typeIdentifier = "com.atproto.identity.getRecommendedDidCredentials"

    public struct Output: ATProtocolCodable {
        public let rotationKeys: [String]?

        public let alsoKnownAs: [String]?

        public let verificationMethods: ATProtocolValueContainer?

        public let services: ATProtocolValueContainer?

        // Standard public initializer
        public init(
            rotationKeys: [String]? = nil,

            alsoKnownAs: [String]? = nil,

            verificationMethods: ATProtocolValueContainer? = nil,

            services: ATProtocolValueContainer? = nil
        ) {
            self.rotationKeys = rotationKeys

            self.alsoKnownAs = alsoKnownAs

            self.verificationMethods = verificationMethods

            self.services = services
        }
    }
}

public extension ATProtoClient.Com.Atproto.Identity {
    /// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
    func getRecommendedDidCredentials() async throws -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?) {
        let endpoint = "/com.atproto.identity.getRecommendedDidCredentials"

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentityGetRecommendedDidCredentials.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
