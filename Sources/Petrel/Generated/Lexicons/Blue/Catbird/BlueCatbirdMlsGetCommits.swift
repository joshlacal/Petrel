import Foundation



// lexicon: 1, id: blue.catbird.mls.getCommits


public struct BlueCatbirdMlsGetCommits { 

    public static let typeIdentifier = "blue.catbird.mls.getCommits"
        
public struct CommitMessage: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.getCommits#commitMessage"
            public let epoch: Int
            public let sender: DID
            public let commitData: Bytes
            public let createdAt: ATProtocolDate

        // Standard initializer
        public init(
            epoch: Int, sender: DID, commitData: Bytes, createdAt: ATProtocolDate
        ) {
            
            self.epoch = epoch
            self.sender = sender
            self.commitData = commitData
            self.createdAt = createdAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.epoch = try container.decode(Int.self, forKey: .epoch)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                
                throw error
            }
            do {
                
                
                self.sender = try container.decode(DID.self, forKey: .sender)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'sender': \(error)")
                
                throw error
            }
            do {
                
                
                self.commitData = try container.decode(Bytes.self, forKey: .commitData)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'commitData': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(epoch, forKey: .epoch)
            
            
            
            
            try container.encode(sender, forKey: .sender)
            
            
            
            
            try container.encode(commitData, forKey: .commitData)
            
            
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(epoch)
            hasher.combine(sender)
            hasher.combine(commitData)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.epoch != other.epoch {
                return false
            }
            
            
            
            
            if self.sender != other.sender {
                return false
            }
            
            
            
            
            if self.commitData != other.commitData {
                return false
            }
            
            
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            
            
            
            
            
            
            let senderValue = try sender.toCBORValue()
            map = map.adding(key: "sender", value: senderValue)
            
            
            
            
            
            
            let commitDataValue = try commitData.toCBORValue()
            map = map.adding(key: "commitData", value: commitDataValue)
            
            
            
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case epoch
            case sender
            case commitData
            case createdAt
        }
    }    
public struct Parameters: Parametrizable {
        public let convoId: String
        public let fromEpoch: Int
        public let toEpoch: Int?
        
        public init(
            convoId: String, 
            fromEpoch: Int, 
            toEpoch: Int? = nil
            ) {
            self.convoId = convoId
            self.fromEpoch = fromEpoch
            self.toEpoch = toEpoch
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convoId: String
        
        public let commits: [CommitMessage]
        
        
        
        // Standard public initializer
        public init(
            
            
            convoId: String,
            
            commits: [CommitMessage]
            
            
        ) {
            
            
            self.convoId = convoId
            
            self.commits = commits
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.commits = try container.decode([CommitMessage].self, forKey: .commits)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(commits, forKey: .commits)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let commitsValue = try commits.toCBORValue()
            map = map.adding(key: "commits", value: commitsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convoId
            case commits
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
                case invalidEpochRange = "InvalidEpochRange.Invalid epoch range specified"
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getCommits

    /// Retrieve MLS commit messages for a conversation within an epoch range
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getCommits(input: BlueCatbirdMlsGetCommits.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetCommits.Output?) {
        let endpoint = "blue.catbird.mls.getCommits"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getCommits")
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
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsGetCommits.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getCommits: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

