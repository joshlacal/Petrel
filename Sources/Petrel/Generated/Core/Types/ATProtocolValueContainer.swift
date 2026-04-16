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
            
            decoders["app.bsky.draft.defs#draftWithId"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftWithId(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftWithId: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftWithId: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draft"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.Draft(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.Draft: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.Draft: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftPost: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftPost: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftView"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftView: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftView: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftEmbedLocalRef"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftEmbedLocalRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftEmbedLocalRef: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftEmbedLocalRef: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftEmbedCaption"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftEmbedCaption(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftEmbedCaption: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftEmbedCaption: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftEmbedImage"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftEmbedImage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftEmbedImage: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftEmbedImage: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftEmbedVideo"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftEmbedVideo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftEmbedVideo: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftEmbedVideo: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftEmbedExternal"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftEmbedExternal(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftEmbedExternal: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftEmbedExternal: \(error)")
                }
            }
            
            decoders["app.bsky.draft.defs#draftEmbedRecord"] = { decoder in
                do {
                    let decodedObject = try AppBskyDraftDefs.DraftEmbedRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyDraftDefs.DraftEmbedRecord: \(error)")
                    return .decodeError("Error decoding AppBskyDraftDefs.DraftEmbedRecord: \(error)")
                }
            }
            
            decoders["app.bsky.video.defs#jobStatus"] = { decoder in
                do {
                    let decodedObject = try AppBskyVideoDefs.JobStatus(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyVideoDefs.JobStatus: \(error)")
                    return .decodeError("Error decoding AppBskyVideoDefs.JobStatus: \(error)")
                }
            }
            
            decoders["app.bsky.contact.defs#matchAndContactIndex"] = { decoder in
                do {
                    let decodedObject = try AppBskyContactDefs.MatchAndContactIndex(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyContactDefs.MatchAndContactIndex: \(error)")
                    return .decodeError("Error decoding AppBskyContactDefs.MatchAndContactIndex: \(error)")
                }
            }
            
            decoders["app.bsky.contact.defs#syncStatus"] = { decoder in
                do {
                    let decodedObject = try AppBskyContactDefs.SyncStatus(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyContactDefs.SyncStatus: \(error)")
                    return .decodeError("Error decoding AppBskyContactDefs.SyncStatus: \(error)")
                }
            }
            
            decoders["app.bsky.contact.defs#notification"] = { decoder in
                do {
                    let decodedObject = try AppBskyContactDefs.Notification(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyContactDefs.Notification: \(error)")
                    return .decodeError("Error decoding AppBskyContactDefs.Notification: \(error)")
                }
            }
            
            decoders["app.bsky.bookmark.defs#bookmark"] = { decoder in
                do {
                    let decodedObject = try AppBskyBookmarkDefs.Bookmark(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyBookmarkDefs.Bookmark: \(error)")
                    return .decodeError("Error decoding AppBskyBookmarkDefs.Bookmark: \(error)")
                }
            }
            
            decoders["app.bsky.bookmark.defs#bookmarkView"] = { decoder in
                do {
                    let decodedObject = try AppBskyBookmarkDefs.BookmarkView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyBookmarkDefs.BookmarkView: \(error)")
                    return .decodeError("Error decoding AppBskyBookmarkDefs.BookmarkView: \(error)")
                }
            }
            
            decoders["app.bsky.embed.defs#aspectRatio"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedDefs.AspectRatio(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedDefs.AspectRatio: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedDefs.AspectRatio: \(error)")
                }
            }
            
            decoders["app.bsky.embed.record"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecord: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord: \(error)")
                }
            }
            
            decoders["app.bsky.embed.record#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecord.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.View: \(error)")
                }
            }
            
            decoders["app.bsky.embed.record#viewRecord"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecord.ViewRecord: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewRecord: \(error)")
                }
            }
            
            decoders["app.bsky.embed.record#viewNotFound"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewNotFound(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecord.ViewNotFound: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewNotFound: \(error)")
                }
            }
            
            decoders["app.bsky.embed.record#viewBlocked"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewBlocked(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecord.ViewBlocked: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewBlocked: \(error)")
                }
            }
            
            decoders["app.bsky.embed.record#viewDetached"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecord.ViewDetached(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecord.ViewDetached: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecord.ViewDetached: \(error)")
                }
            }
            
            decoders["app.bsky.embed.images"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedImages: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages: \(error)")
                }
            }
            
            decoders["app.bsky.embed.images#image"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages.Image(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedImages.Image: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages.Image: \(error)")
                }
            }
            
            decoders["app.bsky.embed.images#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedImages.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages.View: \(error)")
                }
            }
            
            decoders["app.bsky.embed.images#viewImage"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedImages.ViewImage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedImages.ViewImage: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedImages.ViewImage: \(error)")
                }
            }
            
            decoders["app.bsky.embed.recordWithMedia"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecordWithMedia(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecordWithMedia: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecordWithMedia: \(error)")
                }
            }
            
            decoders["app.bsky.embed.recordWithMedia#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedRecordWithMedia.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedRecordWithMedia.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedRecordWithMedia.View: \(error)")
                }
            }
            
            decoders["app.bsky.embed.video"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedVideo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedVideo: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedVideo: \(error)")
                }
            }
            
            decoders["app.bsky.embed.video#caption"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedVideo.Caption(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedVideo.Caption: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedVideo.Caption: \(error)")
                }
            }
            
            decoders["app.bsky.embed.video#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedVideo.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedVideo.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedVideo.View: \(error)")
                }
            }
            
            decoders["app.bsky.embed.external"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedExternal: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal: \(error)")
                }
            }
            
            decoders["app.bsky.embed.external#external"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal.External(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedExternal.External: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal.External: \(error)")
                }
            }
            
            decoders["app.bsky.embed.external#view"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal.View(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedExternal.View: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal.View: \(error)")
                }
            }
            
            decoders["app.bsky.embed.external#viewExternal"] = { decoder in
                do {
                    let decodedObject = try AppBskyEmbedExternal.ViewExternal(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyEmbedExternal.ViewExternal: \(error)")
                    return .decodeError("Error decoding AppBskyEmbedExternal.ViewExternal: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#recordDeleted"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.RecordDeleted(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.RecordDeleted: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.RecordDeleted: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#chatPreference"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.ChatPreference(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.ChatPreference: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.ChatPreference: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#filterablePreference"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.FilterablePreference(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.FilterablePreference: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.FilterablePreference: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#preference"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.Preference(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.Preference: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.Preference: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#preferences"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.Preferences(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.Preferences: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.Preferences: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#activitySubscription"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.ActivitySubscription(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.ActivitySubscription: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.ActivitySubscription: \(error)")
                }
            }
            
            decoders["app.bsky.notification.defs#subjectActivitySubscription"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDefs.SubjectActivitySubscription(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDefs.SubjectActivitySubscription: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDefs.SubjectActivitySubscription: \(error)")
                }
            }
            
            decoders["app.bsky.notification.declaration"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationDeclaration(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationDeclaration: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationDeclaration: \(error)")
                }
            }
            
            decoders["app.bsky.notification.listNotifications#notification"] = { decoder in
                do {
                    let decodedObject = try AppBskyNotificationListNotifications.Notification(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyNotificationListNotifications.Notification: \(error)")
                    return .decodeError("Error decoding AppBskyNotificationListNotifications.Notification: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#skeletonSearchPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonSearchPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.SkeletonSearchPost: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchPost: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#skeletonSearchActor"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonSearchActor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.SkeletonSearchActor: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchActor: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#skeletonSearchStarterPack"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonSearchStarterPack(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.SkeletonSearchStarterPack: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonSearchStarterPack: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#trendingTopic"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.TrendingTopic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.TrendingTopic: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.TrendingTopic: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#skeletonTrend"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.SkeletonTrend(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.SkeletonTrend: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.SkeletonTrend: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#trendView"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.TrendView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.TrendView: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.TrendView: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#threadItemPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.ThreadItemPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.ThreadItemPost: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.ThreadItemPost: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#threadItemNoUnauthenticated"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.ThreadItemNoUnauthenticated(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.ThreadItemNoUnauthenticated: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.ThreadItemNoUnauthenticated: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#threadItemNotFound"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.ThreadItemNotFound(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.ThreadItemNotFound: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.ThreadItemNotFound: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#threadItemBlocked"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.ThreadItemBlocked(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.ThreadItemBlocked: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.ThreadItemBlocked: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#ageAssuranceState"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.AgeAssuranceState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.AgeAssuranceState: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.AgeAssuranceState: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.defs#ageAssuranceEvent"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedDefs.AgeAssuranceEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedDefs.AgeAssuranceEvent: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedDefs.AgeAssuranceEvent: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.getPostThreadOtherV2#threadItem"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedGetPostThreadOtherV2.ThreadItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedGetPostThreadOtherV2.ThreadItem: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedGetPostThreadOtherV2.ThreadItem: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.getPostThreadV2#threadItem"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedGetPostThreadV2.ThreadItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedGetPostThreadV2.ThreadItem: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedGetPostThreadV2.ThreadItem: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.getTaggedSuggestions#suggestion"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedGetTaggedSuggestions.Suggestion(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedGetTaggedSuggestions.Suggestion: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedGetTaggedSuggestions.Suggestion: \(error)")
                }
            }
            
            decoders["app.bsky.unspecced.getConfig#liveNowConfig"] = { decoder in
                do {
                    let decodedObject = try AppBskyUnspeccedGetConfig.LiveNowConfig(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyUnspeccedGetConfig.LiveNowConfig: \(error)")
                    return .decodeError("Error decoding AppBskyUnspeccedGetConfig.LiveNowConfig: \(error)")
                }
            }
            
            decoders["app.bsky.graph.block"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphBlock(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphBlock: \(error)")
                    return .decodeError("Error decoding AppBskyGraphBlock: \(error)")
                }
            }
            
            decoders["app.bsky.graph.getStarterPacksWithMembership#starterPackWithMembership"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphGetStarterPacksWithMembership.StarterPackWithMembership(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphGetStarterPacksWithMembership.StarterPackWithMembership: \(error)")
                    return .decodeError("Error decoding AppBskyGraphGetStarterPacksWithMembership.StarterPackWithMembership: \(error)")
                }
            }
            
            decoders["app.bsky.graph.follow"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphFollow(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphFollow: \(error)")
                    return .decodeError("Error decoding AppBskyGraphFollow: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#listViewBasic"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.ListViewBasic: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListViewBasic: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#listView"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.ListView: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListView: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#listItemView"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListItemView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.ListItemView: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListItemView: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#starterPackView"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.StarterPackView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.StarterPackView: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.StarterPackView: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#starterPackViewBasic"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.StarterPackViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.StarterPackViewBasic: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.StarterPackViewBasic: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#listViewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.ListViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.ListViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.ListViewerState: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#notFoundActor"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.NotFoundActor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.NotFoundActor: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.NotFoundActor: \(error)")
                }
            }
            
            decoders["app.bsky.graph.defs#relationship"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphDefs.Relationship(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphDefs.Relationship: \(error)")
                    return .decodeError("Error decoding AppBskyGraphDefs.Relationship: \(error)")
                }
            }
            
            decoders["app.bsky.graph.getListsWithMembership#listWithMembership"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphGetListsWithMembership.ListWithMembership(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphGetListsWithMembership.ListWithMembership: \(error)")
                    return .decodeError("Error decoding AppBskyGraphGetListsWithMembership.ListWithMembership: \(error)")
                }
            }
            
            decoders["app.bsky.graph.listblock"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphListblock(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphListblock: \(error)")
                    return .decodeError("Error decoding AppBskyGraphListblock: \(error)")
                }
            }
            
            decoders["app.bsky.graph.starterpack"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphStarterpack(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphStarterpack: \(error)")
                    return .decodeError("Error decoding AppBskyGraphStarterpack: \(error)")
                }
            }
            
            decoders["app.bsky.graph.starterpack#feedItem"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphStarterpack.FeedItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphStarterpack.FeedItem: \(error)")
                    return .decodeError("Error decoding AppBskyGraphStarterpack.FeedItem: \(error)")
                }
            }
            
            decoders["app.bsky.graph.listitem"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphListitem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphListitem: \(error)")
                    return .decodeError("Error decoding AppBskyGraphListitem: \(error)")
                }
            }
            
            decoders["app.bsky.graph.list"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphList(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphList: \(error)")
                    return .decodeError("Error decoding AppBskyGraphList: \(error)")
                }
            }
            
            decoders["app.bsky.graph.verification"] = { decoder in
                do {
                    let decodedObject = try AppBskyGraphVerification(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyGraphVerification: \(error)")
                    return .decodeError("Error decoding AppBskyGraphVerification: \(error)")
                }
            }
            
            decoders["app.bsky.feed.generator"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedGenerator(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedGenerator: \(error)")
                    return .decodeError("Error decoding AppBskyFeedGenerator: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#postView"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.PostView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.PostView: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.PostView: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#viewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ViewerState: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#threadContext"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ThreadContext(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ThreadContext: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ThreadContext: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#feedViewPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.FeedViewPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.FeedViewPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.FeedViewPost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#replyRef"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ReplyRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ReplyRef: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ReplyRef: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#reasonRepost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ReasonRepost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ReasonRepost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ReasonRepost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#reasonPin"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ReasonPin(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ReasonPin: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ReasonPin: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#threadViewPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ThreadViewPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ThreadViewPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ThreadViewPost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#notFoundPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.NotFoundPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.NotFoundPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.NotFoundPost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#blockedPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.BlockedPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.BlockedPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.BlockedPost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#blockedAuthor"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.BlockedAuthor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.BlockedAuthor: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.BlockedAuthor: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#generatorView"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.GeneratorView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.GeneratorView: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.GeneratorView: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#generatorViewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.GeneratorViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.GeneratorViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.GeneratorViewerState: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#skeletonFeedPost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.SkeletonFeedPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.SkeletonFeedPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.SkeletonFeedPost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#skeletonReasonRepost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.SkeletonReasonRepost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.SkeletonReasonRepost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.SkeletonReasonRepost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#skeletonReasonPin"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.SkeletonReasonPin(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.SkeletonReasonPin: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.SkeletonReasonPin: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#threadgateView"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.ThreadgateView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.ThreadgateView: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.ThreadgateView: \(error)")
                }
            }
            
            decoders["app.bsky.feed.defs#interaction"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDefs.Interaction(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDefs.Interaction: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDefs.Interaction: \(error)")
                }
            }
            
            decoders["app.bsky.feed.getLikes#like"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedGetLikes.Like(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedGetLikes.Like: \(error)")
                    return .decodeError("Error decoding AppBskyFeedGetLikes.Like: \(error)")
                }
            }
            
            decoders["app.bsky.feed.postgate"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPostgate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedPostgate: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPostgate: \(error)")
                }
            }
            
            decoders["app.bsky.feed.postgate#disableRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPostgate.DisableRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedPostgate.DisableRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPostgate.DisableRule: \(error)")
                }
            }
            
            decoders["app.bsky.feed.threadgate"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedThreadgate: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate: \(error)")
                }
            }
            
            decoders["app.bsky.feed.threadgate#mentionRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.MentionRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedThreadgate.MentionRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.MentionRule: \(error)")
                }
            }
            
            decoders["app.bsky.feed.threadgate#followerRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.FollowerRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedThreadgate.FollowerRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.FollowerRule: \(error)")
                }
            }
            
            decoders["app.bsky.feed.threadgate#followingRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.FollowingRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedThreadgate.FollowingRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.FollowingRule: \(error)")
                }
            }
            
            decoders["app.bsky.feed.threadgate#listRule"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedThreadgate.ListRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedThreadgate.ListRule: \(error)")
                    return .decodeError("Error decoding AppBskyFeedThreadgate.ListRule: \(error)")
                }
            }
            
            decoders["app.bsky.feed.like"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedLike(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedLike: \(error)")
                    return .decodeError("Error decoding AppBskyFeedLike: \(error)")
                }
            }
            
            decoders["app.bsky.feed.repost"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedRepost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedRepost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedRepost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.describeFeedGenerator#feed"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDescribeFeedGenerator.Feed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDescribeFeedGenerator.Feed: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDescribeFeedGenerator.Feed: \(error)")
                }
            }
            
            decoders["app.bsky.feed.describeFeedGenerator#links"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedDescribeFeedGenerator.Links(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedDescribeFeedGenerator.Links: \(error)")
                    return .decodeError("Error decoding AppBskyFeedDescribeFeedGenerator.Links: \(error)")
                }
            }
            
            decoders["app.bsky.feed.post"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedPost: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost: \(error)")
                }
            }
            
            decoders["app.bsky.feed.post#replyRef"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost.ReplyRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedPost.ReplyRef: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost.ReplyRef: \(error)")
                }
            }
            
            decoders["app.bsky.feed.post#entity"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost.Entity(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedPost.Entity: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost.Entity: \(error)")
                }
            }
            
            decoders["app.bsky.feed.post#textSlice"] = { decoder in
                do {
                    let decodedObject = try AppBskyFeedPost.TextSlice(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyFeedPost.TextSlice: \(error)")
                    return .decodeError("Error decoding AppBskyFeedPost.TextSlice: \(error)")
                }
            }
            
            decoders["app.bsky.richtext.facet"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyRichtextFacet: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet: \(error)")
                }
            }
            
            decoders["app.bsky.richtext.facet#mention"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.Mention(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyRichtextFacet.Mention: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.Mention: \(error)")
                }
            }
            
            decoders["app.bsky.richtext.facet#link"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.Link(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyRichtextFacet.Link: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.Link: \(error)")
                }
            }
            
            decoders["app.bsky.richtext.facet#tag"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.Tag(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyRichtextFacet.Tag: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.Tag: \(error)")
                }
            }
            
            decoders["app.bsky.richtext.facet#byteSlice"] = { decoder in
                do {
                    let decodedObject = try AppBskyRichtextFacet.ByteSlice(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyRichtextFacet.ByteSlice: \(error)")
                    return .decodeError("Error decoding AppBskyRichtextFacet.ByteSlice: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#state"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.State(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.State: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.State: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#stateMetadata"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.StateMetadata(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.StateMetadata: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.StateMetadata: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#config"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.Config(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.Config: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.Config: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegion"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegion(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegion: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegion: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleDefault"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleDefault(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleDefault: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleDefault: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleIfDeclaredOverAge"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredOverAge(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredOverAge: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredOverAge: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleIfDeclaredUnderAge"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredUnderAge(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredUnderAge: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfDeclaredUnderAge: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleIfAssuredOverAge"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredOverAge(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredOverAge: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredOverAge: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleIfAssuredUnderAge"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredUnderAge(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredUnderAge: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAssuredUnderAge: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleIfAccountNewerThan"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountNewerThan(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountNewerThan: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountNewerThan: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#configRegionRuleIfAccountOlderThan"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountOlderThan(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountOlderThan: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.ConfigRegionRuleIfAccountOlderThan: \(error)")
                }
            }
            
            decoders["app.bsky.ageassurance.defs#event"] = { decoder in
                do {
                    let decodedObject = try AppBskyAgeassuranceDefs.Event(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyAgeassuranceDefs.Event: \(error)")
                    return .decodeError("Error decoding AppBskyAgeassuranceDefs.Event: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileViewBasic"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileViewBasic: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileViewBasic: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileView"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileView: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileView: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileViewDetailed"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileViewDetailed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileViewDetailed: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileViewDetailed: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileAssociated"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileAssociated(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileAssociated: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileAssociated: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileAssociatedChat"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileAssociatedChat(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileAssociatedChat: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileAssociatedChat: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileAssociatedGerm"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileAssociatedGerm(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileAssociatedGerm: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileAssociatedGerm: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#profileAssociatedActivitySubscription"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ProfileAssociatedActivitySubscription(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ProfileAssociatedActivitySubscription: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ProfileAssociatedActivitySubscription: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#viewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ViewerState: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#knownFollowers"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.KnownFollowers(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.KnownFollowers: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.KnownFollowers: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#verificationState"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.VerificationState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.VerificationState: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.VerificationState: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#verificationView"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.VerificationView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.VerificationView: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.VerificationView: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#preferences"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.Preferences(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.Preferences: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.Preferences: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#adultContentPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.AdultContentPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.AdultContentPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.AdultContentPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#contentLabelPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ContentLabelPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ContentLabelPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ContentLabelPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#savedFeed"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.SavedFeed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.SavedFeed: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.SavedFeed: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#savedFeedsPrefV2"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.SavedFeedsPrefV2(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.SavedFeedsPrefV2: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.SavedFeedsPrefV2: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#savedFeedsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.SavedFeedsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.SavedFeedsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.SavedFeedsPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#personalDetailsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.PersonalDetailsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.PersonalDetailsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.PersonalDetailsPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#declaredAgePref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.DeclaredAgePref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.DeclaredAgePref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.DeclaredAgePref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#feedViewPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.FeedViewPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.FeedViewPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.FeedViewPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#threadViewPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.ThreadViewPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.ThreadViewPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.ThreadViewPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#interestsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.InterestsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.InterestsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.InterestsPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#mutedWord"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.MutedWord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.MutedWord: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.MutedWord: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#mutedWordsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.MutedWordsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.MutedWordsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.MutedWordsPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#hiddenPostsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.HiddenPostsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.HiddenPostsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.HiddenPostsPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#labelersPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.LabelersPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.LabelersPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.LabelersPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#labelerPrefItem"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.LabelerPrefItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.LabelerPrefItem: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.LabelerPrefItem: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#bskyAppStatePref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.BskyAppStatePref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.BskyAppStatePref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.BskyAppStatePref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#bskyAppProgressGuide"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.BskyAppProgressGuide(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.BskyAppProgressGuide: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.BskyAppProgressGuide: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#nux"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.Nux(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.Nux: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.Nux: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#verificationPrefs"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.VerificationPrefs(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.VerificationPrefs: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.VerificationPrefs: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#liveEventPreferences"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.LiveEventPreferences(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.LiveEventPreferences: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.LiveEventPreferences: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#postInteractionSettingsPref"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.PostInteractionSettingsPref(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.PostInteractionSettingsPref: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.PostInteractionSettingsPref: \(error)")
                }
            }
            
            decoders["app.bsky.actor.defs#statusView"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorDefs.StatusView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorDefs.StatusView: \(error)")
                    return .decodeError("Error decoding AppBskyActorDefs.StatusView: \(error)")
                }
            }
            
            decoders["app.bsky.actor.status"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorStatus(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorStatus: \(error)")
                    return .decodeError("Error decoding AppBskyActorStatus: \(error)")
                }
            }
            
            decoders["app.bsky.actor.profile"] = { decoder in
                do {
                    let decodedObject = try AppBskyActorProfile(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyActorProfile: \(error)")
                    return .decodeError("Error decoding AppBskyActorProfile: \(error)")
                }
            }
            
            decoders["app.bsky.labeler.defs#labelerView"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyLabelerDefs.LabelerView: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerView: \(error)")
                }
            }
            
            decoders["app.bsky.labeler.defs#labelerViewDetailed"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerViewDetailed(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyLabelerDefs.LabelerViewDetailed: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerViewDetailed: \(error)")
                }
            }
            
            decoders["app.bsky.labeler.defs#labelerViewerState"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerViewerState(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyLabelerDefs.LabelerViewerState: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerViewerState: \(error)")
                }
            }
            
            decoders["app.bsky.labeler.defs#labelerPolicies"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerDefs.LabelerPolicies(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyLabelerDefs.LabelerPolicies: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerDefs.LabelerPolicies: \(error)")
                }
            }
            
            decoders["app.bsky.labeler.service"] = { decoder in
                do {
                    let decodedObject = try AppBskyLabelerService(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding AppBskyLabelerService: \(error)")
                    return .decodeError("Error decoding AppBskyLabelerService: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#messageRef"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.MessageRef: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageRef: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#messageInput"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageInput(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.MessageInput: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageInput: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#messageView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.MessageView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageView: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#deletedMessageView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.DeletedMessageView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.DeletedMessageView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.DeletedMessageView: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#messageViewSender"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageViewSender(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.MessageViewSender: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageViewSender: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#reactionView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.ReactionView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.ReactionView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.ReactionView: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#reactionViewSender"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.ReactionViewSender(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.ReactionViewSender: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.ReactionViewSender: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#messageAndReactionView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.MessageAndReactionView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.MessageAndReactionView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.MessageAndReactionView: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#convoView"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.ConvoView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.ConvoView: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.ConvoView: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logBeginConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogBeginConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogBeginConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogBeginConvo: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logAcceptConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogAcceptConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogAcceptConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogAcceptConvo: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logLeaveConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogLeaveConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogLeaveConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogLeaveConvo: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logMuteConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogMuteConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogMuteConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogMuteConvo: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logUnmuteConvo"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogUnmuteConvo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogUnmuteConvo: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogUnmuteConvo: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logCreateMessage"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogCreateMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogCreateMessage: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogCreateMessage: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logDeleteMessage"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogDeleteMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogDeleteMessage: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogDeleteMessage: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logReadMessage"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogReadMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogReadMessage: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogReadMessage: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logAddReaction"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogAddReaction(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogAddReaction: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogAddReaction: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.defs#logRemoveReaction"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoDefs.LogRemoveReaction(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoDefs.LogRemoveReaction: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoDefs.LogRemoveReaction: \(error)")
                }
            }
            
            decoders["chat.bsky.convo.sendMessageBatch#batchItem"] = { decoder in
                do {
                    let decodedObject = try ChatBskyConvoSendMessageBatch.BatchItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyConvoSendMessageBatch.BatchItem: \(error)")
                    return .decodeError("Error decoding ChatBskyConvoSendMessageBatch.BatchItem: \(error)")
                }
            }
            
            decoders["chat.bsky.actor.defs#profileViewBasic"] = { decoder in
                do {
                    let decodedObject = try ChatBskyActorDefs.ProfileViewBasic(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyActorDefs.ProfileViewBasic: \(error)")
                    return .decodeError("Error decoding ChatBskyActorDefs.ProfileViewBasic: \(error)")
                }
            }
            
            decoders["chat.bsky.actor.declaration"] = { decoder in
                do {
                    let decodedObject = try ChatBskyActorDeclaration(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyActorDeclaration: \(error)")
                    return .decodeError("Error decoding ChatBskyActorDeclaration: \(error)")
                }
            }
            
            decoders["chat.bsky.moderation.getActorMetadata#metadata"] = { decoder in
                do {
                    let decodedObject = try ChatBskyModerationGetActorMetadata.Metadata(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ChatBskyModerationGetActorMetadata.Metadata: \(error)")
                    return .decodeError("Error decoding ChatBskyModerationGetActorMetadata.Metadata: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getPendingDevices#pendingDeviceAddition"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetPendingDevices.PendingDeviceAddition(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetPendingDevices.PendingDeviceAddition: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetPendingDevices.PendingDeviceAddition: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.registerDevice#keyPackageItem"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatRegisterDevice.KeyPackageItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatRegisterDevice.KeyPackageItem: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatRegisterDevice.KeyPackageItem: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.registerDevice#welcomeMessage"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatRegisterDevice.WelcomeMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatRegisterDevice.WelcomeMessage: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatRegisterDevice.WelcomeMessage: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.commitGroupChange#keyPackageHashEntry"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatCommitGroupChange.KeyPackageHashEntry(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatCommitGroupChange.KeyPackageHashEntry: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatCommitGroupChange.KeyPackageHashEntry: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.commitGroupChange#pendingDeviceAddition"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatCommitGroupChange.PendingDeviceAddition(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatCommitGroupChange.PendingDeviceAddition: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatCommitGroupChange.PendingDeviceAddition: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.defs#convoView"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatDefs.ConvoView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatDefs.ConvoView: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatDefs.ConvoView: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.defs#convoMetadata"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatDefs.ConvoMetadata(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatDefs.ConvoMetadata: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatDefs.ConvoMetadata: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.defs#memberView"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatDefs.MemberView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatDefs.MemberView: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatDefs.MemberView: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.defs#messageView"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatDefs.MessageView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatDefs.MessageView: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatDefs.MessageView: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.defs#keyPackageRef"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatDefs.KeyPackageRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatDefs.KeyPackageRef: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatDefs.KeyPackageRef: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.updateConvo#policyInput"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatUpdateConvo.PolicyInput(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatUpdateConvo.PolicyInput: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatUpdateConvo.PolicyInput: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.updateConvo#policyView"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatUpdateConvo.PolicyView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatUpdateConvo.PolicyView: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatUpdateConvo.PolicyView: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getMessages#gapInfo"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetMessages.GapInfo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetMessages.GapInfo: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetMessages.GapInfo: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.device"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatDevice(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatDevice: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatDevice: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.checkBlocks#blockRelationship"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatCheckBlocks.BlockRelationship(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatCheckBlocks.BlockRelationship: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatCheckBlocks.BlockRelationship: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getKeyPackageStatus#keyPackageStats"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageStats(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageStats: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageStats: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getKeyPackageStatus#deviceKeyPackageCount"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetKeyPackageStatus.DeviceKeyPackageCount(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.DeviceKeyPackageCount: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.DeviceKeyPackageCount: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getKeyPackageStatus#keyPackageStatusItem"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageStatusItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageStatusItem: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageStatusItem: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getKeyPackageStatus#keyPackageHistoryItem"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageHistoryItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageHistoryItem: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetKeyPackageStatus.KeyPackageHistoryItem: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getBlockStatus#blockRelationship"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetBlockStatus.BlockRelationship(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetBlockStatus.BlockRelationship: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetBlockStatus.BlockRelationship: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.getBlockStatus#conversationBlockStatus"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatGetBlockStatus.ConversationBlockStatus(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatGetBlockStatus.ConversationBlockStatus: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatGetBlockStatus.ConversationBlockStatus: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.publishKeyPackages#keyPackageItem"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatPublishKeyPackages.KeyPackageItem(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatPublishKeyPackages.KeyPackageItem: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatPublishKeyPackages.KeyPackageItem: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.publishKeyPackages#keyPackageStats"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatPublishKeyPackages.KeyPackageStats(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatPublishKeyPackages.KeyPackageStats: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatPublishKeyPackages.KeyPackageStats: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.publishKeyPackages#syncResult"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatPublishKeyPackages.SyncResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatPublishKeyPackages.SyncResult: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatPublishKeyPackages.SyncResult: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.publishKeyPackages#publishResult"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatPublishKeyPackages.PublishResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatPublishKeyPackages.PublishResult: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatPublishKeyPackages.PublishResult: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.publishKeyPackages#batchError"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatPublishKeyPackages.BatchError(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatPublishKeyPackages.BatchError: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatPublishKeyPackages.BatchError: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.optIn#optInStatus"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatOptIn.OptInStatus(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatOptIn.OptInStatus: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatOptIn.OptInStatus: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.listDevices#deviceInfo"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatListDevices.DeviceInfo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatListDevices.DeviceInfo: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatListDevices.DeviceInfo: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.policy"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatPolicy(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatPolicy: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatPolicy: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.createConvo#metadataInput"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatCreateConvo.MetadataInput(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatCreateConvo.MetadataInput: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatCreateConvo.MetadataInput: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.createConvo#keyPackageHashEntry"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatCreateConvo.KeyPackageHashEntry(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatCreateConvo.KeyPackageHashEntry: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatCreateConvo.KeyPackageHashEntry: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.createConvo#inviteAction"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatCreateConvo.InviteAction(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatCreateConvo.InviteAction: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatCreateConvo.InviteAction: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#messageEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.MessageEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.MessageEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.MessageEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#memberJoined"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.MemberJoined(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.MemberJoined: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.MemberJoined: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#memberLeft"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.MemberLeft(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.MemberLeft: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.MemberLeft: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#epochAdvanced"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.EpochAdvanced(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.EpochAdvanced: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.EpochAdvanced: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#conversationUpdated"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.ConversationUpdated(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.ConversationUpdated: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.ConversationUpdated: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#reactionEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.ReactionEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.ReactionEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.ReactionEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#typingEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.TypingEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.TypingEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.TypingEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#newDeviceEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.NewDeviceEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.NewDeviceEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.NewDeviceEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#treeChanged"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.TreeChanged(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.TreeChanged: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.TreeChanged: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#infoEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.InfoEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.InfoEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.InfoEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#groupResetEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.GroupResetEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.GroupResetEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.GroupResetEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#membershipChangeEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.MembershipChangeEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.MembershipChangeEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.MembershipChangeEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#readEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.ReadEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.ReadEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.ReadEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#groupInfoRefreshRequestedEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.GroupInfoRefreshRequestedEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.GroupInfoRefreshRequestedEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.GroupInfoRefreshRequestedEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsChat.subscribeEvents#readditionRequestedEvent"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsChatSubscribeEvents.ReadditionRequestedEvent(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsChatSubscribeEvents.ReadditionRequestedEvent: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsChatSubscribeEvents.ReadditionRequestedEvent: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsDS.getFederationPeers#peerRecord"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsDSGetFederationPeers.PeerRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsDSGetFederationPeers.PeerRecord: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsDSGetFederationPeers.PeerRecord: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsDS.getConvoEvents#convoEventEntry"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsDSGetConvoEvents.ConvoEventEntry(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsDSGetConvoEvents.ConvoEventEntry: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsDSGetConvoEvents.ConvoEventEntry: \(error)")
                }
            }
            
            decoders["blue.catbird.mlsDS.deliverMessage#deliveryAck"] = { decoder in
                do {
                    let decodedObject = try BlueCatbirdMlsDSDeliverMessage.DeliveryAck(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding BlueCatbirdMlsDSDeliverMessage.DeliveryAck: \(error)")
                    return .decodeError("Error decoding BlueCatbirdMlsDSDeliverMessage.DeliveryAck: \(error)")
                }
            }
            
            decoders["place.stream.defs#blockView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamDefs.BlockView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamDefs.BlockView: \(error)")
                    return .decodeError("Error decoding PlaceStreamDefs.BlockView: \(error)")
                }
            }
            
            decoders["place.stream.defs#renditions"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamDefs.Renditions(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamDefs.Renditions: \(error)")
                    return .decodeError("Error decoding PlaceStreamDefs.Renditions: \(error)")
                }
            }
            
            decoders["place.stream.defs#rendition"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamDefs.Rendition(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamDefs.Rendition: \(error)")
                    return .decodeError("Error decoding PlaceStreamDefs.Rendition: \(error)")
                }
            }
            
            decoders["place.stream.livestream"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream: \(error)")
                }
            }
            
            decoders["place.stream.livestream#notificationSettings"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream.NotificationSettings(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream.NotificationSettings: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream.NotificationSettings: \(error)")
                }
            }
            
            decoders["place.stream.livestream#livestreamView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream.LivestreamView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream.LivestreamView: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream.LivestreamView: \(error)")
                }
            }
            
            decoders["place.stream.livestream#viewerCount"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream.ViewerCount(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream.ViewerCount: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream.ViewerCount: \(error)")
                }
            }
            
            decoders["place.stream.livestream#teleportArrival"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream.TeleportArrival(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream.TeleportArrival: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream.TeleportArrival: \(error)")
                }
            }
            
            decoders["place.stream.livestream#teleportCanceled"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream.TeleportCanceled(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream.TeleportCanceled: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream.TeleportCanceled: \(error)")
                }
            }
            
            decoders["place.stream.livestream#streamplaceAnything"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLivestream.StreamplaceAnything(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLivestream.StreamplaceAnything: \(error)")
                    return .decodeError("Error decoding PlaceStreamLivestream.StreamplaceAnything: \(error)")
                }
            }
            
            decoders["place.stream.key"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamKey(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamKey: \(error)")
                    return .decodeError("Error decoding PlaceStreamKey: \(error)")
                }
            }
            
            decoders["place.stream.video"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamVideo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamVideo: \(error)")
                    return .decodeError("Error decoding PlaceStreamVideo: \(error)")
                }
            }
            
            decoders["place.stream.segment"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamSegment(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamSegment: \(error)")
                    return .decodeError("Error decoding PlaceStreamSegment: \(error)")
                }
            }
            
            decoders["place.stream.segment#audio"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamSegment.Audio(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamSegment.Audio: \(error)")
                    return .decodeError("Error decoding PlaceStreamSegment.Audio: \(error)")
                }
            }
            
            decoders["place.stream.segment#video"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamSegment.Video(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamSegment.Video: \(error)")
                    return .decodeError("Error decoding PlaceStreamSegment.Video: \(error)")
                }
            }
            
            decoders["place.stream.segment#framerate"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamSegment.Framerate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamSegment.Framerate: \(error)")
                    return .decodeError("Error decoding PlaceStreamSegment.Framerate: \(error)")
                }
            }
            
            decoders["place.stream.segment#segmentView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamSegment.SegmentView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamSegment.SegmentView: \(error)")
                    return .decodeError("Error decoding PlaceStreamSegment.SegmentView: \(error)")
                }
            }
            
            decoders["place.stream.branding.getBranding#brandingAsset"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamBrandingGetBranding.BrandingAsset(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamBrandingGetBranding.BrandingAsset: \(error)")
                    return .decodeError("Error decoding PlaceStreamBrandingGetBranding.BrandingAsset: \(error)")
                }
            }
            
            decoders["place.stream.chat.defs#messageView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatDefs.MessageView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatDefs.MessageView: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatDefs.MessageView: \(error)")
                }
            }
            
            decoders["place.stream.chat.defs#pinnedRecordView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatDefs.PinnedRecordView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatDefs.PinnedRecordView: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatDefs.PinnedRecordView: \(error)")
                }
            }
            
            decoders["place.stream.chat.gate"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatGate(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatGate: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatGate: \(error)")
                }
            }
            
            decoders["place.stream.chat.pinnedRecord"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatPinnedRecord(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatPinnedRecord: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatPinnedRecord: \(error)")
                }
            }
            
            decoders["place.stream.chat.profile"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatProfile(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatProfile: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatProfile: \(error)")
                }
            }
            
            decoders["place.stream.chat.profile#color"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatProfile.Color(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatProfile.Color: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatProfile.Color: \(error)")
                }
            }
            
            decoders["place.stream.chat.message"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatMessage(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatMessage: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatMessage: \(error)")
                }
            }
            
            decoders["place.stream.chat.message#replyRef"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamChatMessage.ReplyRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamChatMessage.ReplyRef: \(error)")
                    return .decodeError("Error decoding PlaceStreamChatMessage.ReplyRef: \(error)")
                }
            }
            
            decoders["place.stream.multistream.defs#targetView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMultistreamDefs.TargetView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMultistreamDefs.TargetView: \(error)")
                    return .decodeError("Error decoding PlaceStreamMultistreamDefs.TargetView: \(error)")
                }
            }
            
            decoders["place.stream.multistream.defs#event"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMultistreamDefs.Event(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMultistreamDefs.Event: \(error)")
                    return .decodeError("Error decoding PlaceStreamMultistreamDefs.Event: \(error)")
                }
            }
            
            decoders["place.stream.multistream.target"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMultistreamTarget(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMultistreamTarget: \(error)")
                    return .decodeError("Error decoding PlaceStreamMultistreamTarget: \(error)")
                }
            }
            
            decoders["place.stream.multistream.listTargets#record"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMultistreamListTargets.Record(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMultistreamListTargets.Record: \(error)")
                    return .decodeError("Error decoding PlaceStreamMultistreamListTargets.Record: \(error)")
                }
            }
            
            decoders["place.stream.ingest.defs#ingest"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamIngestDefs.Ingest(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamIngestDefs.Ingest: \(error)")
                    return .decodeError("Error decoding PlaceStreamIngestDefs.Ingest: \(error)")
                }
            }
            
            decoders["place.stream.server.defs#webhook"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamServerDefs.Webhook(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamServerDefs.Webhook: \(error)")
                    return .decodeError("Error decoding PlaceStreamServerDefs.Webhook: \(error)")
                }
            }
            
            decoders["place.stream.server.defs#rewriteRule"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamServerDefs.RewriteRule(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamServerDefs.RewriteRule: \(error)")
                    return .decodeError("Error decoding PlaceStreamServerDefs.RewriteRule: \(error)")
                }
            }
            
            decoders["place.stream.server.settings"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamServerSettings(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamServerSettings: \(error)")
                    return .decodeError("Error decoding PlaceStreamServerSettings: \(error)")
                }
            }
            
            decoders["place.stream.live.searchActorsTypeahead#actor"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLiveSearchActorsTypeahead.Actor(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLiveSearchActorsTypeahead.Actor: \(error)")
                    return .decodeError("Error decoding PlaceStreamLiveSearchActorsTypeahead.Actor: \(error)")
                }
            }
            
            decoders["place.stream.live.teleport"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLiveTeleport(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLiveTeleport: \(error)")
                    return .decodeError("Error decoding PlaceStreamLiveTeleport: \(error)")
                }
            }
            
            decoders["place.stream.live.viewerCount"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLiveViewerCount(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLiveViewerCount: \(error)")
                    return .decodeError("Error decoding PlaceStreamLiveViewerCount: \(error)")
                }
            }
            
            decoders["place.stream.live.getRecommendations#livestreamRecommendation"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLiveGetRecommendations.LivestreamRecommendation(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLiveGetRecommendations.LivestreamRecommendation: \(error)")
                    return .decodeError("Error decoding PlaceStreamLiveGetRecommendations.LivestreamRecommendation: \(error)")
                }
            }
            
            decoders["place.stream.live.recommendations"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamLiveRecommendations(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamLiveRecommendations: \(error)")
                    return .decodeError("Error decoding PlaceStreamLiveRecommendations: \(error)")
                }
            }
            
            decoders["place.stream.richtext.facet"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamRichtextFacet(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamRichtextFacet: \(error)")
                    return .decodeError("Error decoding PlaceStreamRichtextFacet: \(error)")
                }
            }
            
            decoders["place.stream.muxl.defs#track"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMuxlDefs.Track(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMuxlDefs.Track: \(error)")
                    return .decodeError("Error decoding PlaceStreamMuxlDefs.Track: \(error)")
                }
            }
            
            decoders["place.stream.metadata.distributionPolicy"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMetadataDistributionPolicy(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMetadataDistributionPolicy: \(error)")
                    return .decodeError("Error decoding PlaceStreamMetadataDistributionPolicy: \(error)")
                }
            }
            
            decoders["place.stream.metadata.contentRights"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMetadataContentRights(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMetadataContentRights: \(error)")
                    return .decodeError("Error decoding PlaceStreamMetadataContentRights: \(error)")
                }
            }
            
            decoders["place.stream.metadata.configuration"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMetadataConfiguration(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMetadataConfiguration: \(error)")
                    return .decodeError("Error decoding PlaceStreamMetadataConfiguration: \(error)")
                }
            }
            
            decoders["place.stream.metadata.contentWarnings"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamMetadataContentWarnings(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamMetadataContentWarnings: \(error)")
                    return .decodeError("Error decoding PlaceStreamMetadataContentWarnings: \(error)")
                }
            }
            
            decoders["place.stream.broadcast.defs#broadcastOriginView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamBroadcastDefs.BroadcastOriginView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamBroadcastDefs.BroadcastOriginView: \(error)")
                    return .decodeError("Error decoding PlaceStreamBroadcastDefs.BroadcastOriginView: \(error)")
                }
            }
            
            decoders["place.stream.broadcast.origin"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamBroadcastOrigin(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamBroadcastOrigin: \(error)")
                    return .decodeError("Error decoding PlaceStreamBroadcastOrigin: \(error)")
                }
            }
            
            decoders["place.stream.broadcast.syndication"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamBroadcastSyndication(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamBroadcastSyndication: \(error)")
                    return .decodeError("Error decoding PlaceStreamBroadcastSyndication: \(error)")
                }
            }
            
            decoders["place.stream.badge.defs#badgeView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamBadgeDefs.BadgeView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamBadgeDefs.BadgeView: \(error)")
                    return .decodeError("Error decoding PlaceStreamBadgeDefs.BadgeView: \(error)")
                }
            }
            
            decoders["place.stream.moderation.defs#permissionView"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamModerationDefs.PermissionView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamModerationDefs.PermissionView: \(error)")
                    return .decodeError("Error decoding PlaceStreamModerationDefs.PermissionView: \(error)")
                }
            }
            
            decoders["place.stream.moderation.permission"] = { decoder in
                do {
                    let decodedObject = try PlaceStreamModerationPermission(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding PlaceStreamModerationPermission: \(error)")
                    return .decodeError("Error decoding PlaceStreamModerationPermission: \(error)")
                }
            }
            
            decoders["com.germnetwork.declaration"] = { decoder in
                do {
                    let decodedObject = try ComGermnetworkDeclaration(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComGermnetworkDeclaration: \(error)")
                    return .decodeError("Error decoding ComGermnetworkDeclaration: \(error)")
                }
            }
            
            decoders["com.germnetwork.declaration#messageMe"] = { decoder in
                do {
                    let decodedObject = try ComGermnetworkDeclaration.MessageMe(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComGermnetworkDeclaration.MessageMe: \(error)")
                    return .decodeError("Error decoding ComGermnetworkDeclaration.MessageMe: \(error)")
                }
            }
            
            decoders["com.atproto.temp.checkHandleAvailability#resultAvailable"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoTempCheckHandleAvailability.ResultAvailable(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoTempCheckHandleAvailability.ResultAvailable: \(error)")
                    return .decodeError("Error decoding ComAtprotoTempCheckHandleAvailability.ResultAvailable: \(error)")
                }
            }
            
            decoders["com.atproto.temp.checkHandleAvailability#resultUnavailable"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoTempCheckHandleAvailability.ResultUnavailable(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoTempCheckHandleAvailability.ResultUnavailable: \(error)")
                    return .decodeError("Error decoding ComAtprotoTempCheckHandleAvailability.ResultUnavailable: \(error)")
                }
            }
            
            decoders["com.atproto.temp.checkHandleAvailability#suggestion"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoTempCheckHandleAvailability.Suggestion(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoTempCheckHandleAvailability.Suggestion: \(error)")
                    return .decodeError("Error decoding ComAtprotoTempCheckHandleAvailability.Suggestion: \(error)")
                }
            }
            
            decoders["com.atproto.identity.defs#identityInfo"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoIdentityDefs.IdentityInfo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoIdentityDefs.IdentityInfo: \(error)")
                    return .decodeError("Error decoding ComAtprotoIdentityDefs.IdentityInfo: \(error)")
                }
            }
            
            decoders["com.atproto.admin.defs#statusAttr"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.StatusAttr(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoAdminDefs.StatusAttr: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.StatusAttr: \(error)")
                }
            }
            
            decoders["com.atproto.admin.defs#accountView"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.AccountView(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoAdminDefs.AccountView: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.AccountView: \(error)")
                }
            }
            
            decoders["com.atproto.admin.defs#repoRef"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.RepoRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoAdminDefs.RepoRef: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.RepoRef: \(error)")
                }
            }
            
            decoders["com.atproto.admin.defs#repoBlobRef"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoAdminDefs.RepoBlobRef: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.RepoBlobRef: \(error)")
                }
            }
            
            decoders["com.atproto.admin.defs#threatSignature"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoAdminDefs.ThreatSignature(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoAdminDefs.ThreatSignature: \(error)")
                    return .decodeError("Error decoding ComAtprotoAdminDefs.ThreatSignature: \(error)")
                }
            }
            
            decoders["com.atproto.label.subscribeLabels#labels"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelSubscribeLabels.Labels(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelSubscribeLabels.Labels: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelSubscribeLabels.Labels: \(error)")
                }
            }
            
            decoders["com.atproto.label.subscribeLabels#info"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelSubscribeLabels.Info(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelSubscribeLabels.Info: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelSubscribeLabels.Info: \(error)")
                }
            }
            
            decoders["com.atproto.label.defs#label"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.Label(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelDefs.Label: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.Label: \(error)")
                }
            }
            
            decoders["com.atproto.label.defs#selfLabels"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.SelfLabels(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelDefs.SelfLabels: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.SelfLabels: \(error)")
                }
            }
            
            decoders["com.atproto.label.defs#selfLabel"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.SelfLabel(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelDefs.SelfLabel: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.SelfLabel: \(error)")
                }
            }
            
            decoders["com.atproto.label.defs#labelValueDefinition"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.LabelValueDefinition(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelDefs.LabelValueDefinition: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.LabelValueDefinition: \(error)")
                }
            }
            
            decoders["com.atproto.label.defs#labelValueDefinitionStrings"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLabelDefs.LabelValueDefinitionStrings(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLabelDefs.LabelValueDefinitionStrings: \(error)")
                    return .decodeError("Error decoding ComAtprotoLabelDefs.LabelValueDefinitionStrings: \(error)")
                }
            }
            
            decoders["com.atproto.server.defs#inviteCode"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDefs.InviteCode(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerDefs.InviteCode: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDefs.InviteCode: \(error)")
                }
            }
            
            decoders["com.atproto.server.defs#inviteCodeUse"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDefs.InviteCodeUse(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerDefs.InviteCodeUse: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDefs.InviteCodeUse: \(error)")
                }
            }
            
            decoders["com.atproto.server.listAppPasswords#appPassword"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerListAppPasswords.AppPassword(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerListAppPasswords.AppPassword: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerListAppPasswords.AppPassword: \(error)")
                }
            }
            
            decoders["com.atproto.server.createInviteCodes#accountCodes"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerCreateInviteCodes.AccountCodes(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerCreateInviteCodes.AccountCodes: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerCreateInviteCodes.AccountCodes: \(error)")
                }
            }
            
            decoders["com.atproto.server.createAppPassword#appPassword"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerCreateAppPassword.AppPassword(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerCreateAppPassword.AppPassword: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerCreateAppPassword.AppPassword: \(error)")
                }
            }
            
            decoders["com.atproto.server.describeServer#links"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDescribeServer.Links(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerDescribeServer.Links: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDescribeServer.Links: \(error)")
                }
            }
            
            decoders["com.atproto.server.describeServer#contact"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoServerDescribeServer.Contact(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoServerDescribeServer.Contact: \(error)")
                    return .decodeError("Error decoding ComAtprotoServerDescribeServer.Contact: \(error)")
                }
            }
            
            decoders["com.atproto.lexicon.schema"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoLexiconSchema(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoLexiconSchema: \(error)")
                    return .decodeError("Error decoding ComAtprotoLexiconSchema: \(error)")
                }
            }
            
            decoders["com.atproto.sync.subscribeRepos#commit"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncSubscribeRepos.Commit(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncSubscribeRepos.Commit: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncSubscribeRepos.Commit: \(error)")
                }
            }
            
            decoders["com.atproto.sync.subscribeRepos#sync"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncSubscribeRepos.Sync(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncSubscribeRepos.Sync: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncSubscribeRepos.Sync: \(error)")
                }
            }
            
            decoders["com.atproto.sync.subscribeRepos#identity"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncSubscribeRepos.Identity(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncSubscribeRepos.Identity: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncSubscribeRepos.Identity: \(error)")
                }
            }
            
            decoders["com.atproto.sync.subscribeRepos#account"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncSubscribeRepos.Account(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncSubscribeRepos.Account: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncSubscribeRepos.Account: \(error)")
                }
            }
            
            decoders["com.atproto.sync.subscribeRepos#info"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncSubscribeRepos.Info(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncSubscribeRepos.Info: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncSubscribeRepos.Info: \(error)")
                }
            }
            
            decoders["com.atproto.sync.subscribeRepos#repoOp"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncSubscribeRepos.RepoOp(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncSubscribeRepos.RepoOp: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncSubscribeRepos.RepoOp: \(error)")
                }
            }
            
            decoders["com.atproto.sync.listHosts#host"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncListHosts.Host(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncListHosts.Host: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncListHosts.Host: \(error)")
                }
            }
            
            decoders["com.atproto.sync.listRepos#repo"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncListRepos.Repo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncListRepos.Repo: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncListRepos.Repo: \(error)")
                }
            }
            
            decoders["com.atproto.sync.listReposByCollection#repo"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoSyncListReposByCollection.Repo(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoSyncListReposByCollection.Repo: \(error)")
                    return .decodeError("Error decoding ComAtprotoSyncListReposByCollection.Repo: \(error)")
                }
            }
            
            decoders["com.atproto.repo.strongRef"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoStrongRef(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoStrongRef: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoStrongRef: \(error)")
                }
            }
            
            decoders["com.atproto.repo.defs#commitMeta"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoDefs.CommitMeta(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoDefs.CommitMeta: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoDefs.CommitMeta: \(error)")
                }
            }
            
            decoders["com.atproto.repo.listMissingBlobs#recordBlob"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoListMissingBlobs.RecordBlob(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoListMissingBlobs.RecordBlob: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoListMissingBlobs.RecordBlob: \(error)")
                }
            }
            
            decoders["com.atproto.repo.applyWrites#create"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.Create(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoApplyWrites.Create: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.Create: \(error)")
                }
            }
            
            decoders["com.atproto.repo.applyWrites#update"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.Update(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoApplyWrites.Update: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.Update: \(error)")
                }
            }
            
            decoders["com.atproto.repo.applyWrites#delete"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.Delete(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoApplyWrites.Delete: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.Delete: \(error)")
                }
            }
            
            decoders["com.atproto.repo.applyWrites#createResult"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.CreateResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoApplyWrites.CreateResult: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.CreateResult: \(error)")
                }
            }
            
            decoders["com.atproto.repo.applyWrites#updateResult"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.UpdateResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoApplyWrites.UpdateResult: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.UpdateResult: \(error)")
                }
            }
            
            decoders["com.atproto.repo.applyWrites#deleteResult"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoApplyWrites.DeleteResult(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoApplyWrites.DeleteResult: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoApplyWrites.DeleteResult: \(error)")
                }
            }
            
            decoders["com.atproto.repo.listRecords#record"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoRepoListRecords.Record(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoRepoListRecords.Record: \(error)")
                    return .decodeError("Error decoding ComAtprotoRepoListRecords.Record: \(error)")
                }
            }
            
            decoders["com.atproto.moderation.createReport#modTool"] = { decoder in
                do {
                    let decodedObject = try ComAtprotoModerationCreateReport.ModTool(from: decoder)
                    return .knownType(decodedObject)
                } catch {
                    LogManager.logDebug("Error decoding ComAtprotoModerationCreateReport.ModTool: \(error)")
                    return .decodeError("Error decoding ComAtprotoModerationCreateReport.ModTool: \(error)")
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
           let typeValue = try? container.decode(String.self, forKey: typeName) {


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
                LogManager.logDebug("Error decoding ATProtocolValueContainer: \(error)")
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
            return .array(try decodeAny(from: &arrayContainer))
        }

        if let nestedContainer = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            return try decodeAny(from: nestedContainer)
        }

        LogManager.logDebug("Failed to decode as Array or Object, throwing DecodingError.dataCorruptedError")
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "ATProtocolValueContainer cannot be decoded")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let stringValue):
            try container.encode(stringValue)
        case .number(let intValue):
            try container.encode(intValue)
        case .bigNumber(let bigNumberString):
            try container.encode(bigNumberString)
        case .bool(let boolValue):
            try container.encode(boolValue)
        case .null:
            try container.encodeNil()
        case .link(let linkValue):
            try container.encode(linkValue)
        case .bytes(let bytesValue):
            try container.encode(bytesValue)
        case .array(let arrayValue):
            var arrayContainer = encoder.unkeyedContainer()
            for value in arrayValue {
                try arrayContainer.encode(value)
            }
        case .object(let objectValue):
            var objectContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in objectValue {
                let key = DynamicCodingKeys(stringValue: key)!
                try objectContainer.encode(value, forKey: key)
            }
        case .knownType(let customValue):
            try customValue.encode(to: encoder)
        case .unknownType(_, let unknownValue):
            try unknownValue.encode(to: encoder)
        case .decodeError(let errorMessage):
            throw EncodingError.invalidValue(errorMessage, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode a decoding error."))
        }
    }
    
    // DAG-CBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        switch self {
        case .knownType(let value):
            return try value.toCBORValue()
        case .string(let string):
            return string
        case .number(let number):
            return number
        case .bigNumber(let string):
            return string
        case .object(let dict):
            var map = OrderedCBORMap()
            // Sort keys to maintain consistent ordering
            let sortedKeys = dict.keys.sorted { a, b in
                if a.utf8.count != b.utf8.count {
                    return a.utf8.count < b.utf8.count
                }
                return a < b
            }
            
            for key in sortedKeys {
                if let value = dict[key] {
                    let cborValue = try value.toCBORValue()
                    map = map.adding(key: key, value: cborValue)
                }
            }
            return map
        case .array(let array):
            return try array.map { try $0.toCBORValue() }
        case .bool(let bool):
            return bool
        case .null:
            return nil as Any?
        case .link(let link):
            return link
        case .bytes(let bytes):
            return bytes
        case .unknownType(_, let container):
            return try container.toCBORValue()
        case .decodeError(let error):
            throw DAGCBORError.encodingFailed("Cannot encode error: \(error)")
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
            self.stringValue = String(intValue)
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
                LogManager.logDebug("Failed to decode key: \(key.stringValue)")
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
                array.append(.array(try decodeAny(from: &nestedArrayContainer)))
            } else if let nestedContainer = try? unkeyedContainer.nestedContainer(keyedBy: DynamicCodingKeys.self) {
                array.append(try decodeAny(from: nestedContainer))
            } else {
                LogManager.logDebug("Cannot decode array element at index \(unkeyedContainer.currentIndex)")
                array.append(.decodeError("Cannot decode array element at index \(unkeyedContainer.currentIndex)"))
                break
            }
        }
        return array
    }
}