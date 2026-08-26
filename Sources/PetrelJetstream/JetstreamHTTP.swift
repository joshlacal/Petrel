import Foundation
import Petrel
import PetrelCore

// MARK: - JetstreamKind Codable

extension JetstreamKind: Codable {}

// MARK: - HTTP Transport

public protocol JetstreamHTTPTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
  func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse)
}

public struct URLSessionJetstreamHTTPTransport: JetstreamHTTPTransport {
  public let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }
    return (data, httpResponse)
  }

  public func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    let (url, response) = try await session.download(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }
    return (url, httpResponse)
  }
}

// MARK: - XRPC Error

public struct JetstreamXRPCError: Error, Sendable, Equatable {
  public let status: Int
  public let error: String?
  public let message: String?

  public init(status: Int, error: String? = nil, message: String? = nil) {
    self.status = status
    self.error = error
    self.message = message
  }
}

// MARK: - Snapshot Plan Types

public struct SnapshotPlanRequest: Codable, Sendable, Equatable {
  public var kinds: [JetstreamKind]?
  public var dids: [String]?
  public var collections: [String]?
  public var afterSeq: Int64?
  public var beforeSeq: Int64?

  public init(filter: JetstreamFilter, afterSeq: Int64? = nil, beforeSeq: Int64? = nil) {
    self.kinds = filter.kinds.isEmpty ? nil : filter.kinds
    self.dids = filter.dids.isEmpty ? nil : filter.dids
    self.collections = filter.collections.isEmpty ? nil : filter.collections
    self.afterSeq = afterSeq
    self.beforeSeq = beforeSeq
  }

  public init(
    kinds: [JetstreamKind]? = nil,
    dids: [String]? = nil,
    collections: [String]? = nil,
    afterSeq: Int64? = nil,
    beforeSeq: Int64? = nil
  ) {
    self.kinds = kinds?.isEmpty == true ? nil : kinds
    self.dids = dids?.isEmpty == true ? nil : dids
    self.collections = collections?.isEmpty == true ? nil : collections
    self.afterSeq = afterSeq
    self.beforeSeq = beforeSeq
  }
}

public struct SnapshotBlockRange: Codable, Sendable, Equatable {
  public let first: Int
  public let last: Int

  public init(first: Int, last: Int) {
    self.first = first
    self.last = last
  }
}

public struct SnapshotPlanSegment: Codable, Sendable, Equatable {
  public let name: String
  public let index: Int
  public let checksum: String
  public let minSeq: Int64
  public let maxSeq: Int64
  public let mode: String
  public let blocks: [SnapshotBlockRange]?

  public init(
    name: String,
    index: Int,
    checksum: String,
    minSeq: Int64,
    maxSeq: Int64,
    mode: String,
    blocks: [SnapshotBlockRange]? = nil
  ) {
    self.name = name
    self.index = index
    self.checksum = checksum
    self.minSeq = minSeq
    self.maxSeq = maxSeq
    self.mode = mode
    self.blocks = blocks
  }
}

public struct SnapshotPlanStats: Codable, Sendable, Equatable {
  public let segmentsExamined: Int
  public let segmentsMatched: Int
  public let blocksMatched: Int
  public let entries: Int

  public init(
    segmentsExamined: Int,
    segmentsMatched: Int,
    blocksMatched: Int,
    entries: Int
  ) {
    self.segmentsExamined = segmentsExamined
    self.segmentsMatched = segmentsMatched
    self.blocksMatched = blocksMatched
    self.entries = entries
  }
}

public struct SnapshotPlan: Codable, Sendable, Equatable {
  public let plannedThroughSeq: Int64
  public let sealedTipSeq: Int64
  public let segments: [SnapshotPlanSegment]
  public let stats: SnapshotPlanStats

  public init(
    plannedThroughSeq: Int64,
    sealedTipSeq: Int64,
    segments: [SnapshotPlanSegment],
    stats: SnapshotPlanStats
  ) {
    self.plannedThroughSeq = plannedThroughSeq
    self.sealedTipSeq = sealedTipSeq
    self.segments = segments
    self.stats = stats
  }
}

// MARK: - XRPC Client

public struct JetstreamXRPCClient: Sendable {
  public let host: URL
  public let transport: any JetstreamHTTPTransport

  public init(host: URL, transport: any JetstreamHTTPTransport) {
    self.host = host
    self.transport = transport
  }

  public func planSnapshot(_ request: SnapshotPlanRequest) async throws -> SnapshotPlan {
    let url = try buildURL(nsid: "network.bsky.jetstream.planSnapshot")
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.httpBody = try JSONCoders.encode(request)

    let (data, response) = try await transport.data(for: urlRequest)
    try validateResponse(response, data: data)
    return try JSONCoders.decode(SnapshotPlan.self, from: data)
  }

  public func getBlock(segment: String, blockIndex: Int) async throws -> Data {
    let queryItems = [
      URLQueryItem(name: "segment", value: segment),
      URLQueryItem(name: "blockIndex", value: String(blockIndex)),
    ]
    let url = try buildURL(nsid: "network.bsky.jetstream.getBlock", queryItems: queryItems)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"

    let (data, response) = try await transport.data(for: urlRequest)
    try validateResponse(response, data: data)
    return data
  }

  public func getSegment(name: String) async throws -> URL {
    let queryItems = [
      URLQueryItem(name: "name", value: name),
    ]
    let url = try buildURL(nsid: "network.bsky.jetstream.getSegment", queryItems: queryItems)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"

    let (tempURL, response) = try await transport.download(for: urlRequest)
    guard (200..<300).contains(response.statusCode) else {
      let data = (try? Data(contentsOf: tempURL)) ?? Data()
      try? FileManager.default.removeItem(at: tempURL)
      let envelope = try? JSONCoders.decode(XRPCErrorEnvelope.self, from: data)
      throw JetstreamXRPCError(
        status: response.statusCode,
        error: envelope?.error,
        message: envelope?.message
      )
    }

    let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "jetstream_segment_\(UUID().uuidString)_\(name)"
    )
    try? FileManager.default.removeItem(at: destinationURL)
    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    return destinationURL
  }

  public func getZstdDictionary(id: UInt32? = nil) async throws -> Data {
    var queryItems: [URLQueryItem]?
    if let id {
      queryItems = [URLQueryItem(name: "id", value: String(id))]
    }
    let url = try buildURL(nsid: "network.bsky.jetstream.getZstdDictionary", queryItems: queryItems)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"

    let (data, response) = try await transport.data(for: urlRequest)
    try validateResponse(response, data: data)
    return data
  }

  // MARK: - Private Helpers

  private struct XRPCErrorEnvelope: Decodable {
    let error: String?
    let message: String?
  }

  private func buildURL(nsid: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
    guard var components = URLComponents(url: host, resolvingAgainstBaseURL: true) else {
      throw URLError(.badURL)
    }
    let basePath = components.path
    let trimmedBasePath = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
    components.path = "\(trimmedBasePath)/xrpc/\(nsid)"
    if let queryItems, !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    guard let url = components.url else {
      throw URLError(.badURL)
    }
    return url
  }

  private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
    guard (200..<300).contains(response.statusCode) else {
      let envelope = try? JSONCoders.decode(XRPCErrorEnvelope.self, from: data)
      throw JetstreamXRPCError(
        status: response.statusCode,
        error: envelope?.error,
        message: envelope?.message
      )
    }
  }
}
