import Foundation



// lexicon: 1, id: place.stream.live.subscribeSegments


public struct PlaceStreamLiveSubscribeSegments { 

    public static let typeIdentifier = "place.stream.live.subscribeSegments"    
public struct Parameters: Parametrizable {
        public let streamer: String
        
        public init(
            streamer: String
            ) {
            self.streamer = streamer
            
        }
    }
public enum Message: Codable, Sendable {

    case segment(Segment)


    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {

        case "place.stream.live.subscribeSegments#segment":
            let value = try Segment(from: decoder)
            self = .segment(value)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {

        case .segment(let value):
            try value.encode(to: encoder)

        }
    }
}



}


                           

/// Subscribe to a stream's new segments as they come in!

extension ATProtoClient.Place.Stream.Live {
    
    public func subscribeSegments(
        streamer: String
    ) async throws -> AsyncThrowingStream<PlaceStreamLiveSubscribeSegments.Message, Error> {
        let params = PlaceStreamLiveSubscribeSegments.Parameters(streamer: streamer)
        return try await self.networkService.subscribe(
            endpoint: "place.stream.live.subscribeSegments",
            parameters: params
        )
    }

    /// Alternative signature accepting input struct
    public func subscribeSegments(input: PlaceStreamLiveSubscribeSegments.Parameters) async throws -> AsyncThrowingStream<PlaceStreamLiveSubscribeSegments.Message, Error> {
        return try await self.networkService.subscribe(
            endpoint: "place.stream.live.subscribeSegments",
            parameters: input
        )
    }
    
}
