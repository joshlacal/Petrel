// Lexicon: 1, ID: blue.catbird.mlsChat.subscribeEvents
// Subscribe to live conversation events via WebSocket (consolidates subscribeConvoEvents with streamlined event types) Subscribe to live events (messages, membership changes, epoch advances, conversation updates) via firehose-style DAG-CBOR framing. Requires a valid ticket from getSubscriptionTicket.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatSubscribeEventsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.subscribeEvents"
}

@Serializable(with = BlueCatbirdMlsChatSubscribeEventsMessageUnionSerializer::class)
sealed interface BlueCatbirdMlsChatSubscribeEventsMessageUnion {
    @Serializable
    data class MessageEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMessageEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class ReactionEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReactionEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class TypingEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTypingEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class NewDeviceEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsNewDeviceEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class InfoEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsInfoEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class TreeChanged(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTreeChanged) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class GroupResetEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupResetEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class MembershipChangeEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMembershipChangeEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class GroupInfoRefreshRequestedEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class ReadditionRequestedEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class CircuitBreakerTrippedEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsCircuitBreakerTrippedEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class ResetRequestedEvent(val value: com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsResetRequestedEvent) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : BlueCatbirdMlsChatSubscribeEventsMessageUnion
}

object BlueCatbirdMlsChatSubscribeEventsMessageUnionSerializer : kotlinx.serialization.KSerializer<BlueCatbirdMlsChatSubscribeEventsMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("BlueCatbirdMlsChatSubscribeEventsMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: BlueCatbirdMlsChatSubscribeEventsMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.MessageEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMessageEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#messageEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.ReactionEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReactionEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#reactionEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.TypingEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTypingEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#typingEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.NewDeviceEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsNewDeviceEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#newDeviceEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.InfoEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsInfoEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#infoEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.TreeChanged -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTreeChanged.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#treeChanged")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.GroupResetEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupResetEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#groupResetEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.MembershipChangeEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMembershipChangeEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#membershipChangeEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.GroupInfoRefreshRequestedEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#groupInfoRefreshRequestedEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.ReadditionRequestedEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#readditionRequestedEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.CircuitBreakerTrippedEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsCircuitBreakerTrippedEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#circuitBreakerTrippedEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.ResetRequestedEvent -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsResetRequestedEvent.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("blue.catbird.mlsChat.subscribeEvents#resetRequestedEvent")
                })
            }
            is BlueCatbirdMlsChatSubscribeEventsMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): BlueCatbirdMlsChatSubscribeEventsMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "blue.catbird.mlsChat.subscribeEvents#messageEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.MessageEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMessageEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#reactionEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.ReactionEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReactionEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#typingEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.TypingEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTypingEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#newDeviceEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.NewDeviceEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsNewDeviceEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#infoEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.InfoEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsInfoEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#treeChanged" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.TreeChanged(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTreeChanged.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#groupResetEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.GroupResetEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupResetEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#membershipChangeEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.MembershipChangeEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMembershipChangeEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#groupInfoRefreshRequestedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.GroupInfoRefreshRequestedEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#readditionRequestedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.ReadditionRequestedEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#circuitBreakerTrippedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.CircuitBreakerTrippedEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsCircuitBreakerTrippedEvent.serializer(), element)
            )
            "blue.catbird.mlsChat.subscribeEvents#resetRequestedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.ResetRequestedEvent(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsResetRequestedEvent.serializer(), element)
            )
            else -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.Unexpected(element)
        }
    }
}

    /**
     * A new encrypted message was sent
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMessageEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,        @SerialName("message")
        val message: BlueCatbirdMlsChatDefsMessageView,/** When true, this is an ephemeral signal (typing, read receipt, presence) that should NOT be shown in chat history. Omitted (defaults to false) for regular persistent messages. */        @SerialName("ephemeral")
        val ephemeral: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMessageEvent"
        }
    }

    /**
     * A reaction was added or removed
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsReactionEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Message that was reacted to */        @SerialName("messageId")
        val messageId: String,/** DID of the reactor */        @SerialName("did")
        val did: DID,/** Emoji or short code */        @SerialName("reaction")
        val reaction: String,        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReactionEvent"
        }
    }

    /**
     * A user started or stopped typing
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsTypingEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the typist */        @SerialName("did")
        val did: DID,/** True if started typing, false if stopped */        @SerialName("isTyping")
        val isTyping: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsTypingEvent"
        }
    }

    /**
     * A user registered a new device needing addition to the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsNewDeviceEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base user DID */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name */        @SerialName("deviceName")
        val deviceName: String? = null,/** Full device credential DID (did:plc:user#device-uuid) */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String,/** ID of the pending addition for claim/complete flow */        @SerialName("pendingAdditionId")
        val pendingAdditionId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsNewDeviceEvent"
        }
    }

    /**
     * The canonical MLS tree state changed. Clients must compare confirmationTag against their local state and re-join if mismatched.
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsTreeChanged(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Confirmation tag of the new canonical tree */        @SerialName("confirmationTag")
        val confirmationTag: Bytes,/** New epoch number */        @SerialName("epoch")
        val epoch: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsTreeChanged"
        }
    }

    /**
     * Informational message (heartbeat, notices, or GroupInfo refresh request)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsInfoEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Human-readable info or keep-alive message */        @SerialName("info")
        val info: String,/** Structured info type for programmatic handling */        @SerialName("infoType")
        val infoType: String? = null,/** Conversation ID (for groupInfoRefreshRequested, readditionRequested) */        @SerialName("convoId")
        val convoId: String? = null,/** DID of the requester */        @SerialName("requestedBy")
        val requestedBy: DID? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsInfoEvent"
        }
    }

    /**
     * The MLS group was reset and a new group was created for this conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsGroupResetEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** New MLS group ID after reset */        @SerialName("newGroupId")
        val newGroupId: String,/** Cumulative reset count for this conversation */        @SerialName("resetGeneration")
        val resetGeneration: Int,/** DID of the admin who initiated the reset */        @SerialName("resetBy")
        val resetBy: DID? = null,/** MLS cipher suite used for the new group after reset. */        @SerialName("cipherSuite")
        val cipherSuite: String? = null,/** Optional reason for the reset */        @SerialName("reason")
        val reason: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsGroupResetEvent"
        }
    }

    /**
     * A membership change occurred (joined, left, removed, kicked)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMembershipChangeEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member involved */        @SerialName("did")
        val did: DID,/** Type of membership change */        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMembershipChangeEvent"
        }
    }

    /**
     * A GroupInfo refresh was requested for a conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the requester */        @SerialName("requestedBy")
        val requestedBy: DID? = null,/** When the refresh was requested (RFC3339) */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent"
        }
    }

    /**
     * A member re-addition was requested for a conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member requesting re-addition */        @SerialName("requestedBy")
        val requestedBy: DID? = null,/** When the re-addition was requested (RFC3339) */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent"
        }
    }

    /**
     * The automatic group-reset circuit breaker tripped for this conversation. Auto-reset is disabled; an admin must intervene.
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsCircuitBreakerTrippedEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Recent reset count that triggered the trip */        @SerialName("resetCount")
        val resetCount: Int,/** When the breaker tripped (RFC3339) */        @SerialName("trippedAt")
        val trippedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsCircuitBreakerTrippedEvent"
        }
    }

    /**
     * Phase 2.5: an indirect trigger (quorum vote, system sweep, inline 409/404) has requested a crypto session reset. Active members are invited to respond by submitting new MLS group material via bootstrapResetGroup or commitGroupChange. First commit wins via UNIQUE (conversation_id, generation) tie-break. The previous groupResetEvent is also emitted for backward compatibility during Stage 1.
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsResetRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Server-side opaque id of the crypto_session whose reset was requested (the prior session, now in state='reset_requested') */        @SerialName("cryptoSessionId")
        val cryptoSessionId: String,/** Generation number of the prior session — clients should activate at generation+1 */        @SerialName("generation")
        val generation: Int,/** Which subsystem produced the reset request */        @SerialName("trigger")
        val trigger: String,/** Server-side opaque id of the crypto_session_reset_requested delivery_event for correlation */        @SerialName("requestEventId")
        val requestEventId: String,/** If non-null, only this mls_group_id may activate. Phase 2.5 indirect triggers always emit null here; admin/bootstrap direct flows always provide a value. */        @SerialName("expectedNewMlsGroupId")
        val expectedNewMlsGroupId: String? = null,/** Human-readable reason for the reset */        @SerialName("reason")
        val reason: String? = null,/** When the reset was requested (RFC3339) */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsResetRequestedEvent"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatSubscribeEventsParameters(
// JWT ticket from getSubscriptionTicket for authentication        @SerialName("ticket")
        val ticket: String? = null,// Opaque resume cursor. If provided, resume after this position.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    class BlueCatbirdMlsChatSubscribeEventsMessage

/**
 * Synthetic variants augmenting the generated BlueCatbirdMlsChatSubscribeEventsMessageUnion sealed interface.
 *
 * `Error` surfaces ATProto `op == -1` server error frames; `Unexpected` wraps
 * frames whose header tag did not match any known variant (e.g. new event types
 * added server-side before client regen). Kept as extensions so the lexicon-
 * driven sealed interface stays mechanically faithful to the schema.
 */
data class BlueCatbirdMlsChatSubscribeEventsMessageUnionError(val name: String, val message: String?) : BlueCatbirdMlsChatSubscribeEventsMessageUnion
data class BlueCatbirdMlsChatSubscribeEventsMessageUnionUnexpected(val type: String, val payload: kotlinx.serialization.json.JsonObject) : BlueCatbirdMlsChatSubscribeEventsMessageUnion

/**
 * Subscribe to live conversation events via WebSocket (consolidates subscribeConvoEvents with streamlined event types) Subscribe to live events (messages, membership changes, epoch advances, conversation updates) via firehose-style DAG-CBOR framing. Requires a valid ticket from getSubscriptionTicket.
 *
 * Endpoint: blue.catbird.mlsChat.subscribeEvents
 *
 * The returned [kotlinx.coroutines.flow.Flow] completes (or throws) when the
 * underlying WebSocket disconnects. Reconnect / cursor-resume is the caller's
 * responsibility — wrap in `retryWhen { ... }` with backoff as needed.
 */
fun ATProtoClient.Blue.Catbird.MlsChat.subscribeEvents(
parameters: BlueCatbirdMlsChatSubscribeEventsParameters? = null,
hostOverride: String? = null,
    websocketClient: io.ktor.client.HttpClient? = null,
): kotlinx.coroutines.flow.Flow<BlueCatbirdMlsChatSubscribeEventsMessageUnion> = kotlinx.coroutines.flow.flow {
    val endpoint = "blue.catbird.mlsChat.subscribeEvents"
    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters?.toQueryItems().orEmpty()

    client.openSubscription(endpoint, queryItems, hostOverride, websocketClient) { frame ->
        val decoded: BlueCatbirdMlsChatSubscribeEventsMessageUnion = when (frame) {
            is com.atproto.runtime.subscription.CborFrame.Error ->
                BlueCatbirdMlsChatSubscribeEventsMessageUnionError(frame.name, frame.message)
            is com.atproto.runtime.subscription.CborFrame.Message -> {
                val json = kotlinx.serialization.json.Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                }
                try {
                    when (frame.header.t) {
                        "#messageEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.MessageEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMessageEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#reactionEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.ReactionEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReactionEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#typingEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.TypingEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTypingEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#newDeviceEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.NewDeviceEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsNewDeviceEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#infoEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.InfoEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsInfoEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#treeChanged" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.TreeChanged(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsTreeChanged.serializer(),
                                frame.payload
                            )
                        )
                        "#groupResetEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.GroupResetEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupResetEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#membershipChangeEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.MembershipChangeEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsMembershipChangeEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#groupInfoRefreshRequestedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.GroupInfoRefreshRequestedEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#readditionRequestedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.ReadditionRequestedEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#circuitBreakerTrippedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.CircuitBreakerTrippedEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsCircuitBreakerTrippedEvent.serializer(),
                                frame.payload
                            )
                        )
                        "#resetRequestedEvent" -> BlueCatbirdMlsChatSubscribeEventsMessageUnion.ResetRequestedEvent(
                            json.decodeFromJsonElement(
                                com.atproto.generated.BlueCatbirdMlsChatSubscribeEventsResetRequestedEvent.serializer(),
                                frame.payload
                            )
                        )
                        else -> BlueCatbirdMlsChatSubscribeEventsMessageUnionUnexpected(frame.header.t, frame.payload)
                    }
                } catch (e: Throwable) {
                    BlueCatbirdMlsChatSubscribeEventsMessageUnionUnexpected(frame.header.t, frame.payload)
                }
            }
        }
        emit(decoded)
    }
}
