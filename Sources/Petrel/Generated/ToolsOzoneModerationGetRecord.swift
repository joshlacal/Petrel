import Foundation
internal import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.getRecord

public enum ToolsOzoneModerationGetRecord {
    public static let typeIdentifier = "tools.ozone.moderation.getRecord"
    public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: String?

        public init(
            uri: ATProtocolURI,
            cid: String? = nil
        ) {
            self.uri = uri
            self.cid = cid
        }
    }

    public typealias Output = ToolsOzoneModerationDefs.RecordViewDetail

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case recordNotFound = "RecordNotFound."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about a record.
    func getRecord(input: ToolsOzoneModerationGetRecord.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRecord.Output?) {
        let endpoint = "/tools.ozone.moderation.getRecord"

        let queryItems = input.asQueryItems()
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: false)
        let responseCode = response.statusCode

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRecord.Output.self, from: responseData)
        return (responseCode, decodedData)
    }
}
