import Foundation



// lexicon: 1, id: com.atproto.sync.listHosts


public struct ComAtprotoSyncListHosts { 

    public static let typeIdentifier = "com.atproto.sync.listHosts"
        
public struct Host: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.sync.listHosts#host"
            public let hostname: String
            public let seq: Int?
            public let accountCount: Int?
            public let status: ComAtprotoSyncDefs.HostStatus?

        // Standard initializer
        public init(
            hostname: String, seq: Int?, accountCount: Int?, status: ComAtprotoSyncDefs.HostStatus?
        ) {
            
            self.hostname = hostname
            self.seq = seq
            self.accountCount = accountCount
            self.status = status
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.hostname = try container.decode(String.self, forKey: .hostname)
                
            } catch {
                LogManager.logError("Decoding error for property 'hostname': \(error)")
                throw error
            }
            do {
                
                self.seq = try container.decodeIfPresent(Int.self, forKey: .seq)
                
            } catch {
                LogManager.logError("Decoding error for property 'seq': \(error)")
                throw error
            }
            do {
                
                self.accountCount = try container.decodeIfPresent(Int.self, forKey: .accountCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'accountCount': \(error)")
                throw error
            }
            do {
                
                self.status = try container.decodeIfPresent(ComAtprotoSyncDefs.HostStatus.self, forKey: .status)
                
            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(hostname, forKey: .hostname)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(seq, forKey: .seq)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(accountCount, forKey: .accountCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(hostname)
            if let value = seq {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = accountCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.hostname != other.hostname {
                return false
            }
            
            
            if seq != other.seq {
                return false
            }
            
            
            if accountCount != other.accountCount {
                return false
            }
            
            
            if status != other.status {
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

            
            
            
            let hostnameValue = try hostname.toCBORValue()
            map = map.adding(key: "hostname", value: hostnameValue)
            
            
            
            if let value = seq {
                // Encode optional property even if it's an empty array for CBOR
                
                let seqValue = try value.toCBORValue()
                map = map.adding(key: "seq", value: seqValue)
            }
            
            
            
            if let value = accountCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let accountCountValue = try value.toCBORValue()
                map = map.adding(key: "accountCount", value: accountCountValue)
            }
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case hostname
            case seq
            case accountCount
            case status
        }
    }    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let hosts: [Host]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            hosts: [Host]
            
            
        ) {
            
            self.cursor = cursor
            
            self.hosts = hosts
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.hosts = try container.decode([Host].self, forKey: .hosts)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(hosts, forKey: .hosts)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let hostsValue = try hosts.toCBORValue()
            map = map.adding(key: "hosts", value: hostsValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case hosts
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - listHosts

    /// Enumerates upstream hosts (eg, PDS or relay instances) that this service consumes from. Implemented by relays.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func listHosts(input: ComAtprotoSyncListHosts.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListHosts.Output?) {
        let endpoint = "com.atproto.sync.listHosts"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoSyncListHosts.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
