// Lexicon: 1, ID: place.stream.chat.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamChatDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.chat.defs"
}

@Serializable(with = PlaceStreamChatDefsMessageViewReplyToUnionSerializer::class)
sealed interface PlaceStreamChatDefsMessageViewReplyToUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.PlaceStreamChatDefsMessageView) : PlaceStreamChatDefsMessageViewReplyToUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : PlaceStreamChatDefsMessageViewReplyToUnion
}

object PlaceStreamChatDefsMessageViewReplyToUnionSerializer : kotlinx.serialization.KSerializer<PlaceStreamChatDefsMessageViewReplyToUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("PlaceStreamChatDefsMessageViewReplyToUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: PlaceStreamChatDefsMessageViewReplyToUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is PlaceStreamChatDefsMessageViewReplyToUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamChatDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.chat.defs#messageView")
                })
            }
            is PlaceStreamChatDefsMessageViewReplyToUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): PlaceStreamChatDefsMessageViewReplyToUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "place.stream.chat.defs#messageView" -> PlaceStreamChatDefsMessageViewReplyToUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamChatDefsMessageView.serializer(), element)
            )
            else -> PlaceStreamChatDefsMessageViewReplyToUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class PlaceStreamChatDefsMessageView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,        @SerialName("record")
        val record: JsonElement,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("chatProfile")
        val chatProfile: PlaceStreamChatProfile? = null,        @SerialName("replyTo")
        val replyTo: PlaceStreamChatDefsMessageViewReplyToUnion? = null,/** If true, this message has been deleted or labeled and should be cleared from the cache */        @SerialName("deleted")
        val deleted: Boolean? = null,/** Up to 3 badge tokens to display with the message. First badge is server-controlled, remaining badges are user-settable. Tokens are looked up in badges.json for display info. */        @SerialName("badges")
        val badges: List<PlaceStreamBadgeDefsBadgeView>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamChatDefsMessageView"
        }
    }

    /**
     * View of a pinned chat record with hydrated message data.
     */
    @Serializable
    data class PlaceStreamChatDefsPinnedRecordView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: PlaceStreamChatPinnedRecord,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("pinnedBy")
        val pinnedBy: PlaceStreamChatProfile? = null,        @SerialName("message")
        val message: PlaceStreamChatDefsMessageView? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamChatDefsPinnedRecordView"
        }
    }
