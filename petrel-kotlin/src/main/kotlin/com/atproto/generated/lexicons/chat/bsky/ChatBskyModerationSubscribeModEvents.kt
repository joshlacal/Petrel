// Lexicon: 1, ID: chat.bsky.moderation.subscribeModEvents
// Subscribe to stream of chat events targeted to moderation. Private endpoint.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationSubscribeModEventsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.subscribeModEvents"
}

@Serializable(with = ChatBskyModerationSubscribeModEventsMessageUnionSerializer::class)
sealed interface ChatBskyModerationSubscribeModEventsMessageUnion {
    @Serializable
    data class EventConvoFirstMessage(val value: com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage) : ChatBskyModerationSubscribeModEventsMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyModerationSubscribeModEventsMessageUnion
}

object ChatBskyModerationSubscribeModEventsMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyModerationSubscribeModEventsMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyModerationSubscribeModEventsMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyModerationSubscribeModEventsMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyModerationSubscribeModEventsMessageUnion.EventConvoFirstMessage -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.moderation.subscribeModEvents#eventConvoFirstMessage")
                })
            }
            is ChatBskyModerationSubscribeModEventsMessageUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyModerationSubscribeModEventsMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.moderation.subscribeModEvents#eventConvoFirstMessage" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventConvoFirstMessage(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage.serializer(), element)
            )
            else -> ChatBskyModerationSubscribeModEventsMessageUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class ChatBskyModerationSubscribeModEventsEventConvoFirstMessage(
        @SerialName("convoId")
        val convoId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("messageId")
        val messageId: String? = null,/** The list of DIDs message recipients. Does not include the sender, which is in the `user` field */        @SerialName("recipients")
        val recipients: List<DID>,        @SerialName("rev")
        val rev: String,/** The DID of the message author. */        @SerialName("user")
        val user: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationSubscribeModEventsEventConvoFirstMessage"
        }
    }

@Serializable
    data class ChatBskyModerationSubscribeModEventsParameters(
// The last known event seq number to backfill from. Use '2222222222222' to backfill from the beginning. Don't specify a cursor to listen only for new events.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    class ChatBskyModerationSubscribeModEventsMessage

sealed class ChatBskyModerationSubscribeModEventsError(val name: String, val description: String?) {
        object FutureCursor: ChatBskyModerationSubscribeModEventsError("FutureCursor", "")
        object ConsumerTooSlow: ChatBskyModerationSubscribeModEventsError("ConsumerTooSlow", "If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection.")
    }

/**
 * Synthetic variants augmenting the generated ChatBskyModerationSubscribeModEventsMessageUnion sealed interface.
 *
 * `Error` surfaces ATProto `op == -1` server error frames; `Unexpected` wraps
 * frames whose header tag did not match any known variant (e.g. new event types
 * added server-side before client regen). Kept as extensions so the lexicon-
 * driven sealed interface stays mechanically faithful to the schema.
 */
data class ChatBskyModerationSubscribeModEventsMessageUnionError(val name: String, val message: String?) : ChatBskyModerationSubscribeModEventsMessageUnion
data class ChatBskyModerationSubscribeModEventsMessageUnionUnexpected(val type: String, val payload: kotlinx.serialization.json.JsonObject) : ChatBskyModerationSubscribeModEventsMessageUnion

/**
 * Subscribe to stream of chat events targeted to moderation. Private endpoint.
 *
 * Endpoint: chat.bsky.moderation.subscribeModEvents
 *
 * The returned [kotlinx.coroutines.flow.Flow] completes (or throws) when the
 * underlying WebSocket disconnects. Reconnect / cursor-resume is the caller's
 * responsibility — wrap in `retryWhen { ... }` with backoff as needed.
 */
fun ATProtoClient.Chat.Bsky.Moderation.subscribeModEvents(
parameters: ChatBskyModerationSubscribeModEventsParameters? = null,
hostOverride: String? = null,
    websocketClient: io.ktor.client.HttpClient? = null,
): kotlinx.coroutines.flow.Flow<ChatBskyModerationSubscribeModEventsMessageUnion> = kotlinx.coroutines.flow.flow {
    val endpoint = "chat.bsky.moderation.subscribeModEvents"
    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters?.toQueryItems().orEmpty()

    client.openSubscription(endpoint, queryItems, hostOverride, websocketClient) { frame ->
        val decoded: ChatBskyModerationSubscribeModEventsMessageUnion = when (frame) {
            is com.atproto.runtime.subscription.CborFrame.Error ->
                ChatBskyModerationSubscribeModEventsMessageUnionError(frame.name, frame.message)
            is com.atproto.runtime.subscription.CborFrame.Message -> {
                val json = kotlinx.serialization.json.Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                }
                try {
                    when (frame.header.t) {
                        "#eventConvoFirstMessage" -> ChatBskyModerationSubscribeModEventsMessageUnion.EventConvoFirstMessage(
                            json.decodeFromJsonElement(
                                com.atproto.generated.ChatBskyModerationSubscribeModEventsEventConvoFirstMessage.serializer(),
                                frame.payload
                            )
                        )
                        else -> ChatBskyModerationSubscribeModEventsMessageUnionUnexpected(frame.header.t, frame.payload)
                    }
                } catch (e: Throwable) {
                    ChatBskyModerationSubscribeModEventsMessageUnionUnexpected(frame.header.t, frame.payload)
                }
            }
        }
        emit(decoded)
    }
}
