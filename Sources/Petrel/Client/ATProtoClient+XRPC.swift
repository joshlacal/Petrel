import Foundation

public extension ATProtoClient {
    /// Calls a query (HTTP GET) by NSID, for an endpoint Petrel has no generated method for.
    ///
    /// See ``NetworkService/xrpcQuery(_:parameters:options:)``.
    nonisolated func query(
        _ nsid: String,
        parameters: [URLQueryItem] = [],
        options: XRPCCallOptions = XRPCCallOptions()
    ) async throws -> XRPCResponse {
        try await networkService.xrpcQuery(nsid, parameters: parameters, options: options)
    }

    /// Calls a procedure (HTTP POST) by NSID, for an endpoint Petrel has no generated method for.
    ///
    /// See ``NetworkService/xrpcProcedure(_:parameters:body:options:)``.
    nonisolated func procedure(
        _ nsid: String,
        parameters: [URLQueryItem] = [],
        body: XRPCBody? = nil,
        options: XRPCCallOptions = XRPCCallOptions()
    ) async throws -> XRPCResponse {
        try await networkService.xrpcProcedure(nsid, parameters: parameters, body: body, options: options)
    }
}
