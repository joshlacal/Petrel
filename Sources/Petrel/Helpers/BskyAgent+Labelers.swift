import Foundation

public extension BskyAgent {
    // MARK: Labeler configuration

    /// The `atproto-accept-labelers` entries for a set of user-chosen labelers:
    /// the app labelers with `redact`, followed by the user's labelers.
    func acceptedLabelers(userLabelers: [DID]) -> [AcceptedLabeler] {
        AcceptedLabeler.deduplicated(
            appLabelers.map { AcceptedLabeler(did: $0, redact: true) }
                + userLabelers.map { AcceptedLabeler(did: $0, redact: false) }
        )
    }

    /// Requests labels from the app labelers plus the given labelers on every
    /// subsequent call of this client.
    ///
    /// ``getPreferences()``, ``addLabeler(_:)`` and ``removeLabeler(_:)`` call
    /// this for you with the labelers stored in the account's preferences.
    ///
    /// - Parameter userLabelers: The labelers the user subscribes to.
    func configureLabelers(_ userLabelers: [DID]) async {
        await networkService.setHeader(
            name: "atproto-accept-labelers",
            value: AcceptedLabeler.headerValue(for: acceptedLabelers(userLabelers: userLabelers))
        )
    }

    // MARK: Label definitions

    /// Fetches the label value definitions published by labelers and
    /// interprets them for the moderation engine.
    ///
    /// The app labelers are always included.
    ///
    /// - Parameter labelers: The labelers to fetch, in addition to the app labelers.
    /// - Returns: Interpreted definitions keyed by labeler DID, ready for
    ///   ``ModerationOptions/labelDefs``.
    func getLabelDefinitions(for labelers: [DID]) async throws -> [DID: [InterpretedLabelValueDefinition]] {
        var dids: [DID] = []
        for did in appLabelers + labelers where !dids.contains(did) {
            dids.append(did)
        }
        guard !dids.isEmpty else { return [:] }

        let nsid = "app.bsky.labeler.getServices"
        let query = dids.map { URLQueryItem(name: "dids", value: $0.didString()) }
            + [URLQueryItem(name: "detailed", value: "true")]
        let output = try await xrpcQuery(nsid, query: query)
            .decode(AppBskyLabelerGetServices.Output.self, nsid: nsid)

        var definitions: [DID: [InterpretedLabelValueDefinition]] = [:]
        for view in output.views {
            if case let .appBskyLabelerDefsLabelerViewDetailed(detailed) = view {
                definitions[detailed.creator.did] = Moderation.interpretLabelValueDefinitions(detailed)
            }
        }
        return definitions
    }

    /// Fetches the label definitions of the labelers named in moderation preferences.
    func getLabelDefinitions(for prefs: ModerationPrefs) async throws -> [DID: [InterpretedLabelValueDefinition]] {
        try await getLabelDefinitions(for: prefs.labelers.map(\.did))
    }

    /// Everything the moderation engine needs for the signed-in user: their
    /// DID, their preferences, and the definitions of their labelers.
    ///
    /// Reads the preferences and the labelers' services; cache the result and
    /// refresh it when preferences change.
    ///
    /// ```swift
    /// let options = try await client.bsky.moderationOptions()
    /// let decision = Moderation.moderatePost(post, options: options)
    /// ```
    func moderationOptions() async throws -> ModerationOptions {
        let prefs = try await getPreferences().moderationPrefs
        let userDid = try? await did()
        let labelDefs = try await getLabelDefinitions(for: prefs)
        return ModerationOptions(userDid: userDid, prefs: prefs, labelDefs: labelDefs)
    }

    // MARK: Reports

    /// Files a moderation report, optionally addressed to a specific labeler.
    ///
    /// The destination is chosen for this request only: nothing is written to
    /// the client's shared headers, so other calls are unaffected.
    ///
    /// - Parameters:
    ///   - input: The report.
    ///   - labeler: The labeler to send the report to, or `nil` for the PDS's
    ///     default moderation service.
    @discardableResult
    func createModerationReport(
        _ input: ComAtprotoModerationCreateReport.Input,
        labeler: DID? = nil
    ) async throws -> ComAtprotoModerationCreateReport.Output {
        try await procedure(
            "com.atproto.moderation.createReport",
            input: input,
            as: ComAtprotoModerationCreateReport.Output.self,
            options: BskyCallOptions(proxy: labeler.map(ServiceProxy.labeler))
        )
    }
}
