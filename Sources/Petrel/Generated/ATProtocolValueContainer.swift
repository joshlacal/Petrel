public indirect enum ATProtocolValueContainer: ATProtocolCodable, ATProtocolValue {
    case knownType(any ATProtocolValue)
    case string(String)
    case number(Int)
    case bigNumber(String)
    case object([String: ATProtocolValueContainer])
    case array([ATProtocolValueContainer])
    case bool(Bool)
    case null
    case link(ATProtoLink)
    case bytes(Bytes)
    case unknownType(String, ATProtocolValueContainer)
    case decodeError(String)

    // A factory for resolving decoders based on type string
    struct TypeDecoderFactory {
        typealias DecoderFunction = @Sendable (Decoder) throws -> ATProtocolValueContainer

        private let decoders: [String: DecoderFunction]

        init() {
            var decoders: [String: DecoderFunction] = [:]

            decoders["tools.ozone.server.getConfig#serviceConfig"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneServerGetConfig.ServiceConfig(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneServerGetConfig.ServiceConfig: \(error)")
                    return .decodeError("Error decoding ToolsOzoneServerGetConfig.ServiceConfig: \(error)")
                }
            }

            decoders["tools.ozone.server.getConfig#viewerConfig"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneServerGetConfig.ViewerConfig(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneServerGetConfig.ViewerConfig: \(error)")
                    return .decodeError("Error decoding ToolsOzoneServerGetConfig.ViewerConfig: \(error)")
                }
            }

            decoders["tools.ozone.team.defs#member"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneTeamDefs.Member(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneTeamDefs.Member: \(error)")
                    return .decodeError("Error decoding ToolsOzoneTeamDefs.Member: \(error)")
                }
            }

            decoders["tools.ozone.signature.defs#sigDetail"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneSignatureDefs.SigDetail(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneSignatureDefs.SigDetail: \(error)")
                    return .decodeError("Error decoding ToolsOzoneSignatureDefs.SigDetail: \(error)")
                }
            }

            decoders["tools.ozone.signature.findRelatedAccounts#relatedAccount"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneSignatureFindRelatedAccounts.RelatedAccount(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneSignatureFindRelatedAccounts.RelatedAccount: \(error)")
                    return .decodeError("Error decoding ToolsOzoneSignatureFindRelatedAccounts.RelatedAccount: \(error)")
                }
            }

            decoders["tools.ozone.communication.defs#templateView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneCommunicationDefs.TemplateView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneCommunicationDefs.TemplateView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneCommunicationDefs.TemplateView: \(error)")
                }
            }

            decoders["tools.ozone.setting.defs#option"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneSettingDefs.Option(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneSettingDefs.Option: \(error)")
                    return .decodeError("Error decoding ToolsOzoneSettingDefs.Option: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventView: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventViewDetail"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventViewDetail(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventViewDetail: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventViewDetail: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#subjectStatusView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.SubjectStatusView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.SubjectStatusView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.SubjectStatusView: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#accountStats"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.AccountStats(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.AccountStats: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.AccountStats: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#recordsStats"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RecordsStats(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RecordsStats: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RecordsStats: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventTakedown"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventTakedown(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventTakedown: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventTakedown: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventReverseTakedown"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventReverseTakedown(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventReverseTakedown: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventReverseTakedown: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventResolveAppeal"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventResolveAppeal(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventResolveAppeal: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventResolveAppeal: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventComment"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventComment(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventComment: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventComment: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventReport"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventReport(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventReport: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventReport: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventLabel"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventLabel(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventLabel: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventLabel: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventPriorityScore"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventPriorityScore(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventPriorityScore: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventPriorityScore: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventAcknowledge"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventAcknowledge(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventAcknowledge: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventAcknowledge: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventEscalate"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventEscalate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventEscalate: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventEscalate: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventMute"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventMute(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventMute: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventMute: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventUnmute"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventUnmute(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventUnmute: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventUnmute: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventMuteReporter"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventMuteReporter(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventMuteReporter: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventMuteReporter: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventUnmuteReporter"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventUnmuteReporter(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventUnmuteReporter: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventUnmuteReporter: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventEmail"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventEmail(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventEmail: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventEmail: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventDivert"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventDivert(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventDivert: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventDivert: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#modEventTag"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModEventTag(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModEventTag: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModEventTag: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#accountEvent"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.AccountEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.AccountEvent: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.AccountEvent: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#identityEvent"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.IdentityEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.IdentityEvent: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.IdentityEvent: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#recordEvent"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RecordEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RecordEvent: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RecordEvent: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#repoView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RepoView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RepoView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RepoView: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#repoViewDetail"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RepoViewDetail(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RepoViewDetail: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RepoViewDetail: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#repoViewNotFound"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RepoViewNotFound(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RepoViewNotFound: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RepoViewNotFound: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#recordView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RecordView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RecordView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RecordView: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#recordViewDetail"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RecordViewDetail(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RecordViewDetail: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RecordViewDetail: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#recordViewNotFound"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RecordViewNotFound(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RecordViewNotFound: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RecordViewNotFound: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#moderation"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.Moderation(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.Moderation: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.Moderation: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#moderationDetail"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ModerationDetail(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ModerationDetail: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ModerationDetail: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#blobView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.BlobView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.BlobView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.BlobView: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#imageDetails"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ImageDetails(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ImageDetails: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ImageDetails: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#videoDetails"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.VideoDetails(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.VideoDetails: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.VideoDetails: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#accountHosting"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.AccountHosting(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.AccountHosting: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.AccountHosting: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#recordHosting"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.RecordHosting(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.RecordHosting: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.RecordHosting: \(error)")
                }
            }

            decoders["tools.ozone.moderation.defs#reporterStats"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneModerationDefs.ReporterStats(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneModerationDefs.ReporterStats: \(error)")
                    return .decodeError("Error decoding ToolsOzoneModerationDefs.ReporterStats: \(error)")
                }
            }

            decoders["app.bsky.embed.images"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedImages: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages: \(error)")
                }
            }

            decoders["app.bsky.embed.images#image"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages.Image(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedImages.Image: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages.Image: \(error)")
                }
            }

            decoders["app.bsky.embed.images#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedImages.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages.View: \(error)")
                }
            }

            decoders["app.bsky.embed.images#viewImage"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages.ViewImage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedImages.ViewImage: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages.ViewImage: \(error)")
                }
            }

            decoders["app.bsky.embed.video"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedVideo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedVideo: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedVideo: \(error)")
                }
            }

            decoders["app.bsky.embed.video#caption"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedVideo.Caption(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedVideo.Caption: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedVideo.Caption: \(error)")
                }
            }

            decoders["app.bsky.embed.video#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedVideo.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedVideo.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedVideo.View: \(error)")
                }
            }

            decoders["app.bsky.video.defs#jobStatus"] = { decoder in
                do {
                    let decodedObject = try AppBskyVideoDefs.JobStatus(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyVideoDefs.JobStatus: \(error)")
                    return .decodeError("Error decoding AppBskyVideoDefs.JobStatus: \(error)")
                }
            }

            decoders["app.bsky.embed.external"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedExternal: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal: \(error)")
                }
            }

            decoders["app.bsky.embed.external#external"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal.External(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedExternal.External: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal.External: \(error)")
                }
            }

            decoders["app.bsky.embed.external#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedExternal.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal.View: \(error)")
                }
            }

            decoders["app.bsky.embed.external#viewExternal"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal.ViewExternal(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedExternal.ViewExternal: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal.ViewExternal: \(error)")
                }
            }

            decoders["app.bsky.embed.recordWithMedia"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecordWithMedia(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecordWithMedia: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecordWithMedia: \(error)")
                }
            }

            decoders["app.bsky.embed.recordWithMedia#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecordWithMedia.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecordWithMedia.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecordWithMedia.View: \(error)")
                }
            }

            decoders["app.bsky.embed.defs#aspectRatio"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedDefs.AspectRatio(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedDefs.AspectRatio: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedDefs.AspectRatio: \(error)")
                }
            }

            decoders["tools.ozone.set.defs#set"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneSetDefs.Set(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneSetDefs.Set: \(error)")
                    return .decodeError("Error decoding ToolsOzoneSetDefs.Set: \(error)")
                }
            }

            decoders["tools.ozone.set.defs#setView"] = { decoder in
                do {
                    let decodedObject = try ToolsOzoneSetDefs.SetView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ToolsOzoneSetDefs.SetView: \(error)")
                    return .decodeError("Error decoding ToolsOzoneSetDefs.SetView: \(error)")
                }
            }

            decoders["app.bsky.unspecced.defs#skeletonSearchPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonSearchPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchPost: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchPost: \(error)")
                }
            }

            decoders["app.bsky.unspecced.defs#skeletonSearchActor"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonSearchActor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchActor: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchActor: \(error)")
                }
            }

            decoders["app.bsky.unspecced.defs#skeletonSearchStarterPack"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonSearchStarterPack(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchStarterPack: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchStarterPack: \(error)")
                }
            }

            decoders["app.bsky.unspecced.defs#trendingTopic"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.TrendingTopic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyUnspeccedDefs.TrendingTopic: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.TrendingTopic: \(error)")
                }
            }

            decoders["app.bsky.embed.record"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecord: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord: \(error)")
                }
            }

            decoders["app.bsky.embed.record#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecord.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.View: \(error)")
                }
            }

            decoders["app.bsky.embed.record#viewRecord"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecord.ViewRecord: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewRecord: \(error)")
                }
            }

            decoders["app.bsky.embed.record#viewNotFound"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewNotFound(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecord.ViewNotFound: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewNotFound: \(error)")
                }
            }

            decoders["app.bsky.embed.record#viewBlocked"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewBlocked(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecord.ViewBlocked: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewBlocked: \(error)")
                }
            }

            decoders["app.bsky.embed.record#viewDetached"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewDetached(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyEmbedRecord.ViewDetached: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewDetached: \(error)")
                }
            }

            decoders["app.bsky.unspecced.getTaggedSuggestions#suggestion"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedGetTaggedSuggestions.Suggestion(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyUnspeccedGetTaggedSuggestions.Suggestion: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedGetTaggedSuggestions.Suggestion: \(error)")
                }
            }

            decoders["app.bsky.notification.listNotifications#notification"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationListNotifications.Notification(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyNotificationListNotifications.Notification: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationListNotifications.Notification: \(error)")
                }
            }

            decoders["app.bsky.graph.starterpack"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphStarterpack(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphStarterpack: \(error)")
                    return .decodeError("Error decoding AppBskyGraphStarterpack: \(error)")
                }
            }

            decoders["app.bsky.graph.starterpack#feedItem"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphStarterpack.FeedItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphStarterpack.FeedItem: \(error)")
                    return .decodeError("Error decoding AppBskyGraphStarterpack.FeedItem: \(error)")
                }
            }

            decoders["app.bsky.graph.follow"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphFollow(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphFollow: \(error)")
                    return .decodeError("Error decoding AppBskyGraphFollow: \(error)")
                }
            }

            decoders["app.bsky.graph.block"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphBlock(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphBlock: \(error)")
                    return .decodeError("Error decoding AppBskyGraphBlock: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#listViewBasic"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.ListViewBasic: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListViewBasic: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#listView"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.ListView: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListView: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#listItemView"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListItemView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.ListItemView: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListItemView: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#starterPackView"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.StarterPackView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.StarterPackView: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.StarterPackView: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#starterPackViewBasic"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.StarterPackViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.StarterPackViewBasic: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.StarterPackViewBasic: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#listViewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.ListViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListViewerState: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#notFoundActor"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.NotFoundActor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.NotFoundActor: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.NotFoundActor: \(error)")
                }
            }

            decoders["app.bsky.graph.defs#relationship"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.Relationship(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphDefs.Relationship: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.Relationship: \(error)")
                }
            }

            decoders["app.bsky.graph.listblock"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphListblock(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphListblock: \(error)")
                    return .decodeError("Error decoding AppBskyGraphListblock: \(error)")
                }
            }

            decoders["app.bsky.graph.listitem"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphListitem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphListitem: \(error)")
                    return .decodeError("Error decoding AppBskyGraphListitem: \(error)")
                }
            }

            decoders["app.bsky.graph.list"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphList(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyGraphList: \(error)")
                    return .decodeError("Error decoding AppBskyGraphList: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#postView"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.PostView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.PostView: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.PostView: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#viewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ViewerState: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#threadContext"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ThreadContext(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ThreadContext: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ThreadContext: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#feedViewPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.FeedViewPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.FeedViewPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.FeedViewPost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#replyRef"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ReplyRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ReplyRef: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ReplyRef: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#reasonRepost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ReasonRepost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ReasonRepost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ReasonRepost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#reasonPin"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ReasonPin(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ReasonPin: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ReasonPin: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#threadViewPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ThreadViewPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ThreadViewPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ThreadViewPost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#notFoundPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.NotFoundPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.NotFoundPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.NotFoundPost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#blockedPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.BlockedPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.BlockedPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.BlockedPost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#blockedAuthor"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.BlockedAuthor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.BlockedAuthor: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.BlockedAuthor: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#generatorView"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.GeneratorView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.GeneratorView: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.GeneratorView: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#generatorViewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.GeneratorViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.GeneratorViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.GeneratorViewerState: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#skeletonFeedPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.SkeletonFeedPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.SkeletonFeedPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.SkeletonFeedPost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#skeletonReasonRepost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.SkeletonReasonRepost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.SkeletonReasonRepost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.SkeletonReasonRepost: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#skeletonReasonPin"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.SkeletonReasonPin(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.SkeletonReasonPin: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.SkeletonReasonPin: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#threadgateView"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ThreadgateView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.ThreadgateView: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ThreadgateView: \(error)")
                }
            }

            decoders["app.bsky.feed.defs#interaction"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.Interaction(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDefs.Interaction: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.Interaction: \(error)")
                }
            }

            decoders["app.bsky.feed.generator"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedGenerator(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedGenerator: \(error)")
                    return .decodeError("Error decoding AppBskyFeedGenerator: \(error)")
                }
            }

            decoders["app.bsky.feed.threadgate"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedThreadgate: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate: \(error)")
                }
            }

            decoders["app.bsky.feed.threadgate#mentionRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.MentionRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedThreadgate.MentionRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.MentionRule: \(error)")
                }
            }

            decoders["app.bsky.feed.threadgate#followerRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.FollowerRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedThreadgate.FollowerRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.FollowerRule: \(error)")
                }
            }

            decoders["app.bsky.feed.threadgate#followingRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.FollowingRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedThreadgate.FollowingRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.FollowingRule: \(error)")
                }
            }

            decoders["app.bsky.feed.threadgate#listRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.ListRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedThreadgate.ListRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.ListRule: \(error)")
                }
            }

            decoders["app.bsky.feed.getLikes#like"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedGetLikes.Like(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedGetLikes.Like: \(error)")
                    return .decodeError("Error decoding AppBskyFeedGetLikes.Like: \(error)")
                }
            }

            decoders["app.bsky.feed.postgate"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPostgate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedPostgate: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPostgate: \(error)")
                }
            }

            decoders["app.bsky.feed.postgate#disableRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPostgate.DisableRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedPostgate.DisableRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPostgate.DisableRule: \(error)")
                }
            }

            decoders["app.bsky.feed.repost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedRepost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedRepost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedRepost: \(error)")
                }
            }

            decoders["app.bsky.feed.describeFeedGenerator#feed"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDescribeFeedGenerator.Feed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDescribeFeedGenerator.Feed: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDescribeFeedGenerator.Feed: \(error)")
                }
            }

            decoders["app.bsky.feed.describeFeedGenerator#links"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDescribeFeedGenerator.Links(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedDescribeFeedGenerator.Links: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDescribeFeedGenerator.Links: \(error)")
                }
            }

            decoders["app.bsky.feed.like"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedLike(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedLike: \(error)")
                    return .decodeError("Error decoding AppBskyFeedLike: \(error)")
                }
            }

            decoders["app.bsky.feed.post"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost: \(error)")
                }
            }

            decoders["app.bsky.feed.post#replyRef"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost.ReplyRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedPost.ReplyRef: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost.ReplyRef: \(error)")
                }
            }

            decoders["app.bsky.feed.post#entity"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost.Entity(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedPost.Entity: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost.Entity: \(error)")
                }
            }

            decoders["app.bsky.feed.post#textSlice"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost.TextSlice(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyFeedPost.TextSlice: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost.TextSlice: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#profileViewBasic"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ProfileViewBasic: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileViewBasic: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#profileView"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ProfileView: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileView: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#profileViewDetailed"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileViewDetailed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ProfileViewDetailed: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileViewDetailed: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#profileAssociated"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileAssociated(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ProfileAssociated: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileAssociated: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#profileAssociatedChat"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileAssociatedChat(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ProfileAssociatedChat: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileAssociatedChat: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#viewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ViewerState: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#knownFollowers"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.KnownFollowers(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.KnownFollowers: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.KnownFollowers: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#preferences"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.Preferences(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.Preferences: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.Preferences: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#adultContentPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.AdultContentPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.AdultContentPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.AdultContentPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#contentLabelPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ContentLabelPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ContentLabelPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ContentLabelPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#savedFeed"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.SavedFeed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.SavedFeed: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.SavedFeed: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#savedFeedsPrefV2"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.SavedFeedsPrefV2(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.SavedFeedsPrefV2: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.SavedFeedsPrefV2: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#savedFeedsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.SavedFeedsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.SavedFeedsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.SavedFeedsPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#personalDetailsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.PersonalDetailsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.PersonalDetailsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.PersonalDetailsPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#feedViewPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.FeedViewPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.FeedViewPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.FeedViewPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#threadViewPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ThreadViewPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.ThreadViewPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ThreadViewPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#interestsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.InterestsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.InterestsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.InterestsPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#mutedWord"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.MutedWord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.MutedWord: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.MutedWord: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#mutedWordsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.MutedWordsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.MutedWordsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.MutedWordsPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#hiddenPostsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.HiddenPostsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.HiddenPostsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.HiddenPostsPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#labelersPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.LabelersPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.LabelersPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.LabelersPref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#labelerPrefItem"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.LabelerPrefItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.LabelerPrefItem: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.LabelerPrefItem: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#bskyAppStatePref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.BskyAppStatePref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.BskyAppStatePref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.BskyAppStatePref: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#bskyAppProgressGuide"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.BskyAppProgressGuide(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.BskyAppProgressGuide: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.BskyAppProgressGuide: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#nux"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.Nux(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.Nux: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.Nux: \(error)")
                }
            }

            decoders["app.bsky.actor.defs#postInteractionSettingsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.PostInteractionSettingsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorDefs.PostInteractionSettingsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.PostInteractionSettingsPref: \(error)")
                }
            }

            decoders["app.bsky.labeler.service"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerService(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyLabelerService: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerService: \(error)")
                }
            }

            decoders["app.bsky.labeler.defs#labelerView"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyLabelerDefs.LabelerView: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerView: \(error)")
                }
            }

            decoders["app.bsky.labeler.defs#labelerViewDetailed"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerViewDetailed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyLabelerDefs.LabelerViewDetailed: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerViewDetailed: \(error)")
                }
            }

            decoders["app.bsky.labeler.defs#labelerViewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyLabelerDefs.LabelerViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerViewerState: \(error)")
                }
            }

            decoders["app.bsky.labeler.defs#labelerPolicies"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerPolicies(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyLabelerDefs.LabelerPolicies: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerPolicies: \(error)")
                }
            }

            decoders["app.bsky.richtext.facet"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyRichtextFacet: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet: \(error)")
                }
            }

            decoders["app.bsky.richtext.facet#mention"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.Mention(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyRichtextFacet.Mention: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.Mention: \(error)")
                }
            }

            decoders["app.bsky.richtext.facet#link"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.Link(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyRichtextFacet.Link: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.Link: \(error)")
                }
            }

            decoders["app.bsky.richtext.facet#tag"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.Tag(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyRichtextFacet.Tag: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.Tag: \(error)")
                }
            }

            decoders["app.bsky.richtext.facet#byteSlice"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.ByteSlice(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyRichtextFacet.ByteSlice: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.ByteSlice: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#messageRef"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.MessageRef: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageRef: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#messageInput"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageInput(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.MessageInput: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageInput: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#messageView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.MessageView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageView: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#deletedMessageView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.DeletedMessageView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.DeletedMessageView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.DeletedMessageView: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#messageViewSender"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageViewSender(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.MessageViewSender: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageViewSender: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#convoView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.ConvoView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.ConvoView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.ConvoView: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logBeginConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogBeginConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogBeginConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogBeginConvo: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logAcceptConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogAcceptConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogAcceptConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogAcceptConvo: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logLeaveConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogLeaveConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogLeaveConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogLeaveConvo: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logMuteConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogMuteConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogMuteConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogMuteConvo: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logUnmuteConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogUnmuteConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogUnmuteConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogUnmuteConvo: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logCreateMessage"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogCreateMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogCreateMessage: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogCreateMessage: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logDeleteMessage"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogDeleteMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogDeleteMessage: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogDeleteMessage: \(error)")
                }
            }

            decoders["chat.bsky.convo.defs#logReadMessage"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogReadMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoDefs.LogReadMessage: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogReadMessage: \(error)")
                }
            }

            decoders["app.bsky.actor.profile"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorProfile(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding AppBskyActorProfile: \(error)")
                    return .decodeError("Error decoding AppBskyActorProfile: \(error)")
                }
            }

            decoders["chat.bsky.convo.sendMessageBatch#batchItem"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoSendMessageBatch.BatchItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyConvoSendMessageBatch.BatchItem: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoSendMessageBatch.BatchItem: \(error)")
                }
            }

            decoders["chat.bsky.moderation.getActorMetadata#metadata"] = { decoder in
                do {
                    let decodedObject = try ChatBskyModerationGetActorMetadata.Metadata(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyModerationGetActorMetadata.Metadata: \(error)")
                    return .decodeError("Error decoding ChatBskyModerationGetActorMetadata.Metadata: \(error)")
                }
            }

            decoders["chat.bsky.actor.defs#profileViewBasic"] = { decoder in
                do {
                    let decodedObject = try ChatBskyActorDefs.ProfileViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyActorDefs.ProfileViewBasic: \(error)")
                    return .decodeError("Error decoding ChatBskyActorDefs.ProfileViewBasic: \(error)")
                }
            }

            decoders["chat.bsky.actor.declaration"] = { decoder in
                do {
                    let decodedObject = try ChatBskyActorDeclaration(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ChatBskyActorDeclaration: \(error)")
                    return .decodeError("Error decoding ChatBskyActorDeclaration: \(error)")
                }
            }

            decoders["com.atproto.identity.defs#identityInfo"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoIdentityDefs.IdentityInfo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoIdentityDefs.IdentityInfo: \(error)")
                    return .decodeError("Error decoding ComAtprotoIdentityDefs.IdentityInfo: \(error)")
                }
            }

            decoders["com.atproto.admin.defs#statusAttr"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.StatusAttr(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoAdminDefs.StatusAttr: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.StatusAttr: \(error)")
                }
            }

            decoders["com.atproto.admin.defs#accountView"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.AccountView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoAdminDefs.AccountView: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.AccountView: \(error)")
                }
            }

            decoders["com.atproto.admin.defs#repoRef"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoAdminDefs.RepoRef: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.RepoRef: \(error)")
                }
            }

            decoders["com.atproto.admin.defs#repoBlobRef"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoAdminDefs.RepoBlobRef: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.RepoBlobRef: \(error)")
                }
            }

            decoders["com.atproto.admin.defs#threatSignature"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.ThreatSignature(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoAdminDefs.ThreatSignature: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.ThreatSignature: \(error)")
                }
            }

            decoders["com.atproto.label.defs#label"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.Label(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoLabelDefs.Label: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.Label: \(error)")
                }
            }

            decoders["com.atproto.label.defs#selfLabels"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.SelfLabels(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoLabelDefs.SelfLabels: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.SelfLabels: \(error)")
                }
            }

            decoders["com.atproto.label.defs#selfLabel"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.SelfLabel(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoLabelDefs.SelfLabel: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.SelfLabel: \(error)")
                }
            }

            decoders["com.atproto.label.defs#labelValueDefinition"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.LabelValueDefinition(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoLabelDefs.LabelValueDefinition: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.LabelValueDefinition: \(error)")
                }
            }

            decoders["com.atproto.label.defs#labelValueDefinitionStrings"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.LabelValueDefinitionStrings(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoLabelDefs.LabelValueDefinitionStrings: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.LabelValueDefinitionStrings: \(error)")
                }
            }

            decoders["com.atproto.server.defs#inviteCode"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDefs.InviteCode(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerDefs.InviteCode: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDefs.InviteCode: \(error)")
                }
            }

            decoders["com.atproto.server.defs#inviteCodeUse"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDefs.InviteCodeUse(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerDefs.InviteCodeUse: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDefs.InviteCodeUse: \(error)")
                }
            }

            decoders["com.atproto.server.createAppPassword#appPassword"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerCreateAppPassword.AppPassword(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerCreateAppPassword.AppPassword: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerCreateAppPassword.AppPassword: \(error)")
                }
            }

            decoders["com.atproto.server.describeServer#links"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDescribeServer.Links(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerDescribeServer.Links: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDescribeServer.Links: \(error)")
                }
            }

            decoders["com.atproto.server.describeServer#contact"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDescribeServer.Contact(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerDescribeServer.Contact: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDescribeServer.Contact: \(error)")
                }
            }

            decoders["com.atproto.server.listAppPasswords#appPassword"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerListAppPasswords.AppPassword(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerListAppPasswords.AppPassword: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerListAppPasswords.AppPassword: \(error)")
                }
            }

            decoders["com.atproto.server.createInviteCodes#accountCodes"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerCreateInviteCodes.AccountCodes(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoServerCreateInviteCodes.AccountCodes: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerCreateInviteCodes.AccountCodes: \(error)")
                }
            }

            decoders["com.atproto.lexicon.schema"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLexiconSchema(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoLexiconSchema: \(error)")
                    return .decodeError("Error decoding ComAtprotoLexiconSchema: \(error)")
                }
            }

            decoders["com.atproto.repo.defs#commitMeta"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoDefs.CommitMeta(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoDefs.CommitMeta: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoDefs.CommitMeta: \(error)")
                }
            }

            decoders["com.atproto.sync.listRepos#repo"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncListRepos.Repo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoSyncListRepos.Repo: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncListRepos.Repo: \(error)")
                }
            }

            decoders["com.atproto.repo.strongRef"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoStrongRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoStrongRef: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoStrongRef: \(error)")
                }
            }

            decoders["com.atproto.repo.listMissingBlobs#recordBlob"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoListMissingBlobs.RecordBlob(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoListMissingBlobs.RecordBlob: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoListMissingBlobs.RecordBlob: \(error)")
                }
            }

            decoders["com.atproto.sync.listReposByCollection#repo"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncListReposByCollection.Repo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoSyncListReposByCollection.Repo: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncListReposByCollection.Repo: \(error)")
                }
            }

            decoders["com.atproto.repo.listRecords#record"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoListRecords.Record(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoListRecords.Record: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoListRecords.Record: \(error)")
                }
            }

            decoders["com.atproto.repo.applyWrites#create"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.Create(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoApplyWrites.Create: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.Create: \(error)")
                }
            }

            decoders["com.atproto.repo.applyWrites#update"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.Update(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoApplyWrites.Update: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.Update: \(error)")
                }
            }

            decoders["com.atproto.repo.applyWrites#delete"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.Delete(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoApplyWrites.Delete: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.Delete: \(error)")
                }
            }

            decoders["com.atproto.repo.applyWrites#createResult"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.CreateResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoApplyWrites.CreateResult: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.CreateResult: \(error)")
                }
            }

            decoders["com.atproto.repo.applyWrites#updateResult"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.UpdateResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoApplyWrites.UpdateResult: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.UpdateResult: \(error)")
                }
            }

            decoders["com.atproto.repo.applyWrites#deleteResult"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.DeleteResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logError("Error decoding ComAtprotoRepoApplyWrites.DeleteResult: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.DeleteResult: \(error)")
                }
            }

            self.decoders = decoders
        }

        func decoder(for type: String) -> DecoderFunction? {
            return decoders[type]
        }
    }

    private static let decoderFactory = TypeDecoderFactory()

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        if let typeName = container.allKeys.first(where: { $0.stringValue == "$type" }),
           let typeValue = try? container.decode(String.self, forKey: typeName)
        {
            if let decoderFunction = ATProtocolValueContainer.decoderFactory.decoder(for: typeValue) {
                self = try decoderFunction(decoder)
            } else {
                let unknownObject = try ATProtocolValueContainer.decodeAny(from: container)
                self = .unknownType(typeValue, unknownObject)
            }
        } else {
            do {
                self = try ATProtocolValueContainer.decodeSingleValue(from: decoder)
            } catch {
                LogManager.logError("Error decoding ATProtocolValueContainer: \(error)")
                self = .decodeError("Decoding error: \(error)")
            }
        }
    }

    private static func decodeSingleValue(from decoder: Decoder) throws -> ATProtocolValueContainer {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            return .string(stringValue)
        }
        if let intValue = try? container.decode(Int.self) {
            return .number(intValue)
        }
        if let bigNumberString = try? container.decode(String.self) {
            return .bigNumber(bigNumberString)
        }
        if let boolValue = try? container.decode(Bool.self) {
            return .bool(boolValue)
        }
        if container.decodeNil() {
            return .null
        }

        if var arrayContainer = try? decoder.unkeyedContainer() {
            return try .array(decodeAny(from: &arrayContainer))
        }

        if let nestedContainer = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            return try decodeAny(from: nestedContainer)
        }

        LogManager.logError("Failed to decode as Array or Object, throwing DecodingError.dataCorruptedError")
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "ATProtocolValueContainer cannot be decoded")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(stringValue):
            try container.encode(stringValue)
        case let .number(intValue):
            try container.encode(intValue)
        case let .bigNumber(bigNumberString):
            try container.encode(bigNumberString)
        case let .bool(boolValue):
            try container.encode(boolValue)
        case .null:
            try container.encodeNil()
        case let .link(linkValue):
            try container.encode(linkValue)
        case let .bytes(bytesValue):
            try container.encode(bytesValue)
        case let .array(arrayValue):
            var arrayContainer = encoder.unkeyedContainer()
            for value in arrayValue {
                try arrayContainer.encode(value)
            }
        case let .object(objectValue):
            var objectContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in objectValue {
                let key = DynamicCodingKeys(stringValue: key)!
                try objectContainer.encode(value, forKey: key)
            }
        case let .knownType(customValue):
            try customValue.encode(to: encoder)
        case let .unknownType(_, unknownValue):
            try unknownValue.encode(to: encoder)
        case let .decodeError(errorMessage):
            throw EncodingError.invalidValue(errorMessage, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode a decoding error."))
        }
    }

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.intValue = intValue
            stringValue = String(intValue)
        }
    }

    private static func decodeAny(from container: KeyedDecodingContainer<DynamicCodingKeys>) throws -> ATProtocolValueContainer {
        var dictionary = [String: ATProtocolValueContainer]()
        for key in container.allKeys {
            if let boolValue = try? container.decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = .bool(boolValue)
            } else if let intValue = try? container.decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = .number(intValue)
            } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = .bigNumber(String(doubleValue))
            } else if let stringValue = try? container.decode(String.self, forKey: key) {
                dictionary[key.stringValue] = .string(stringValue)
            } else if let nestedContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key) {
                dictionary[key.stringValue] = try decodeAny(from: nestedContainer)
            } else if var arrayContainer = try? container.nestedUnkeyedContainer(forKey: key) {
                var array = [ATProtocolValueContainer]()
                while !arrayContainer.isAtEnd {
                    let value = try arrayContainer.decode(ATProtocolValueContainer.self)
                    array.append(value)
                }
                dictionary[key.stringValue] = .array(array)
            } else {
                LogManager.logError("Failed to decode key: \(key.stringValue)")
                dictionary[key.stringValue] = .decodeError("Cannot decode value for key: \(key.stringValue)")
            }
        }
        return .object(dictionary)
    }

    private static func decodeAny(from unkeyedContainer: inout UnkeyedDecodingContainer) throws -> [ATProtocolValueContainer] {
        var array = [ATProtocolValueContainer]()
        while !unkeyedContainer.isAtEnd {
            if let value = try? unkeyedContainer.decode(Bool.self) {
                array.append(.bool(value))
            } else if let value = try? unkeyedContainer.decode(Int.self) {
                array.append(.number(value))
            } else if let value = try? unkeyedContainer.decode(Double.self) {
                array.append(.bigNumber(String(value)))
            } else if let value = try? unkeyedContainer.decode(String.self) {
                array.append(.string(value))
            } else if var nestedArrayContainer = try? unkeyedContainer.nestedUnkeyedContainer() {
                try array.append(.array(decodeAny(from: &nestedArrayContainer)))
            } else if let nestedContainer = try? unkeyedContainer.nestedContainer(keyedBy: DynamicCodingKeys.self) {
                try array.append(decodeAny(from: nestedContainer))
            } else {
                LogManager.logError("Cannot decode array element at index \(unkeyedContainer.currentIndex)")
                array.append(.decodeError("Cannot decode array element at index \(unkeyedContainer.currentIndex)"))
                break
            }
        }
        return array
    }
}
