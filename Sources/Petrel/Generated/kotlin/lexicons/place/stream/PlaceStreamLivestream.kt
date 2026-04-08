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

@Serializable(with = PlaceStreamLivestreamStreamplaceAnythingLivestreamUnionSerializer::class)
sealed interface PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion {
    @Serializable
    data class LivestreamView(val value: com.atproto.generated.PlaceStreamLivestreamLivestreamView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class ViewerCount(val value: com.atproto.generated.PlaceStreamLivestreamViewerCount) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class TeleportArrival(val value: com.atproto.generated.PlaceStreamLivestreamTeleportArrival) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class TeleportCanceled(val value: com.atproto.generated.PlaceStreamLivestreamTeleportCanceled) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class BlockView(val value: com.atproto.generated.PlaceStreamDefsBlockView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class Renditions(val value: com.atproto.generated.PlaceStreamDefsRenditions) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class Rendition(val value: com.atproto.generated.PlaceStreamDefsRendition) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class MessageView(val value: com.atproto.generated.PlaceStreamChatDefsMessageView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class PinnedRecordView(val value: com.atproto.generated.PlaceStreamChatDefsPinnedRecordView) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion
}

object PlaceStreamLivestreamStreamplaceAnythingLivestreamUnionSerializer : kotlinx.serialization.KSerializer<PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.LivestreamView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamLivestreamLivestreamView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.livestream#livestreamView")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.ViewerCount -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamLivestreamViewerCount.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.livestream#viewerCount")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.TeleportArrival -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamLivestreamTeleportArrival.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.livestream#teleportArrival")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.TeleportCanceled -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamLivestreamTeleportCanceled.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.livestream#teleportCanceled")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.BlockView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamDefsBlockView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.defs#blockView")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.Renditions -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamDefsRenditions.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.defs#renditions")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.Rendition -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamDefsRendition.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.defs#rendition")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamChatDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.chat.defs#messageView")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.PinnedRecordView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamChatDefsPinnedRecordView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.chat.defs#pinnedRecordView")
                })
            }
            is PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "place.stream.livestream#livestreamView" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.LivestreamView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamLivestreamLivestreamView.serializer(), element)
            )
            "place.stream.livestream#viewerCount" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.ViewerCount(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamLivestreamViewerCount.serializer(), element)
            )
            "place.stream.livestream#teleportArrival" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.TeleportArrival(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamLivestreamTeleportArrival.serializer(), element)
            )
            "place.stream.livestream#teleportCanceled" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.TeleportCanceled(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamLivestreamTeleportCanceled.serializer(), element)
            )
            "place.stream.defs#blockView" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.BlockView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamDefsBlockView.serializer(), element)
            )
            "place.stream.defs#renditions" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.Renditions(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamDefsRenditions.serializer(), element)
            )
            "place.stream.defs#rendition" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.Rendition(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamDefsRendition.serializer(), element)
            )
            "place.stream.chat.defs#messageView" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamChatDefsMessageView.serializer(), element)
            )
            "place.stream.chat.defs#pinnedRecordView" -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.PinnedRecordView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamChatDefsPinnedRecordView.serializer(), element)
            )
            else -> PlaceStreamLivestreamStreamplaceAnythingLivestreamUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class PlaceStreamLivestreamNotificationSettings(
/** Whether this livestream should trigger a push notification to followers. */        @SerialName("pushNotification")
        val pushNotification: Boolean? = null    ) {
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
        val viewerCount: PlaceStreamLivestreamViewerCount? = null    ) {
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
        val chatProfile: PlaceStreamChatProfile? = null,/** How many viewers are arriving from this teleport */        @SerialName("viewerCount")
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
