// Lexicon: 1, ID: place.stream.livestream
// Record announcing a livestream is happening
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLivestreamDefs {
    const val TYPE_IDENTIFIER = "place.stream.livestream"
}

@Serializable
sealed interface PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion {
    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamLivestreamLivestreamView")
    data class PlaceStreamLivestreamLivestreamView(val value: PlaceStreamLivestreamLivestreamView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamLivestreamViewerCount")
    data class PlaceStreamLivestreamViewerCount(val value: PlaceStreamLivestreamViewerCount) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamLivestreamTeleportArrival")
    data class PlaceStreamLivestreamTeleportArrival(val value: PlaceStreamLivestreamTeleportArrival) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamLivestreamTeleportCanceled")
    data class PlaceStreamLivestreamTeleportCanceled(val value: PlaceStreamLivestreamTeleportCanceled) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamDefsBlockView")
    data class PlaceStreamDefsBlockView(val value: PlaceStreamDefsBlockView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamDefsRenditions")
    data class PlaceStreamDefsRenditions(val value: PlaceStreamDefsRenditions) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamDefsRendition")
    data class PlaceStreamDefsRendition(val value: PlaceStreamDefsRendition) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamChatDefsMessageView")
    data class PlaceStreamChatDefsMessageView(val value: PlaceStreamChatDefsMessageView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("place.stream.livestream#PlaceStreamChatDefsPinnedRecordView")
    data class PlaceStreamChatDefsPinnedRecordView(val value: PlaceStreamChatDefsPinnedRecordView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion
}

    @Serializable
    data class PlaceStreamLivestreamNotificationSettings(
/** Whether this livestream should trigger a push notification to followers. */        @SerialName("pushNotification")
        val pushNotification: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLivestreamNotificationSettings"
        }
    }

    @Serializable
    data class PlaceStreamLivestreamLivestreamView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,        @SerialName("record")
        val record: JsonElement,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,/** The number of viewers watching this livestream. Use when you can't reasonably use #viewerCount directly. */        @SerialName("viewerCount")
        val viewerCount: PlaceStreamLivestreamViewerCount?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLivestreamLivestreamView"
        }
    }

    @Serializable
    data class PlaceStreamLivestreamViewerCount(
        @SerialName("count")
        val count: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLivestreamViewerCount"
        }
    }

    @Serializable
    data class PlaceStreamLivestreamTeleportArrival(
/** The URI of the teleport record */        @SerialName("teleportUri")
        val teleportUri: ATProtocolURI,/** The streamer who is teleporting their viewers here */        @SerialName("source")
        val source: AppBskyActorDefsProfileViewBasic,/** The chat profile of the source streamer */        @SerialName("chatProfile")
        val chatProfile: PlaceStreamChatProfile?,/** How many viewers are arriving from this teleport */        @SerialName("viewerCount")
        val viewerCount: Int,/** When this teleport started */        @SerialName("startsAt")
        val startsAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLivestreamTeleportArrival"
        }
    }

    @Serializable
    data class PlaceStreamLivestreamTeleportCanceled(
/** The URI of the teleport record that was canceled */        @SerialName("teleportUri")
        val teleportUri: ATProtocolURI,/** Why this teleport was canceled */        @SerialName("reason")
        val reason: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLivestreamTeleportCanceled"
        }
    }

    @Serializable
    data class PlaceStreamLivestreamStreamplaceAnything(
        @SerialName("livestream")
        val livestream: PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLivestreamStreamplaceAnything"
        }
    }

    /**
     * Record announcing a livestream is happening
     */
    @Serializable
    data class PlaceStreamLivestream(
/** The title of the livestream, as it will be announced to followers. */        @SerialName("title")
        val title: String,/** The URL where this stream can be found. This is primarily a hint for other Streamplace nodes to locate and replicate the stream. */        @SerialName("url")
        val url: URI? = null,/** Client-declared timestamp when this livestream started. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Client-declared timestamp when this livestream was last seen by the Streamplace station. */        @SerialName("lastSeenAt")
        val lastSeenAt: ATProtocolDate? = null,/** Client-declared timestamp when this livestream ended. Ended livestreams are not supposed to start up again. */        @SerialName("endedAt")
        val endedAt: ATProtocolDate? = null,/** Time in seconds after which this livestream should be automatically ended if idle. Zero means no timeout. */        @SerialName("idleTimeoutSeconds")
        val idleTimeoutSeconds: Int? = null,/** The post that announced this livestream. */        @SerialName("post")
        val post: ComAtprotoRepoStrongRef? = null,/** The source of the livestream, if available, in a User Agent format: `<product> / <product-version> <comment>` e.g. Streamplace/0.7.5 iOS */        @SerialName("agent")
        val agent: String? = null,/** The primary URL where this livestream can be viewed, if available. */        @SerialName("canonicalUrl")
        val canonicalUrl: URI? = null,        @SerialName("thumb")
        val thumb: Blob? = null,        @SerialName("notificationSettings")
        val notificationSettings: PlaceStreamLivestreamNotificationSettings? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
