import Foundation

/// Where the preferences helpers read and write the raw preference array.
///
/// The production implementation talks to the account's PDS. Tests substitute
/// an in-memory store so every setter can be exercised without a network.
protocol BskyPreferencesBackend: Sendable {
    /// Returns the `preferences` array of `app.bsky.actor.getPreferences`, untouched.
    func loadPreferences() async throws -> [BskyJSON]

    /// Replaces the stored array through `app.bsky.actor.putPreferences`.
    func savePreferences(_ preferences: [BskyJSON]) async throws

    /// Applies the user's labeler subscriptions to subsequent requests.
    func configureLabelers(_ labelers: [AcceptedLabeler]) async
}

/// The PDS-backed preferences store.
struct BskyNetworkPreferencesBackend: BskyPreferencesBackend {
    let agent: BskyAgent

    func loadPreferences() async throws -> [BskyJSON] {
        let nsid = "app.bsky.actor.getPreferences"
        let response = try await agent.xrpcQuery(nsid)
        guard let preferences = try response.json(nsid: nsid)["preferences"]?.arrayValue else {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Missing preferences array")
        }
        return preferences
    }

    func savePreferences(_ preferences: [BskyJSON]) async throws {
        _ = try await agent.xrpcProcedure(
            "app.bsky.actor.putPreferences",
            body: .object(["preferences": .array(preferences)])
        )
    }

    func configureLabelers(_ labelers: [AcceptedLabeler]) async {
        await agent.networkService.setHeader(
            name: "atproto-accept-labelers",
            value: AcceptedLabeler.headerValue(for: labelers)
        )
    }
}

extension BskyAgent {
    /// The store preference helpers use for this agent.
    var preferencesBackend: any BskyPreferencesBackend {
        BskyNetworkPreferencesBackend(agent: self)
    }
}
