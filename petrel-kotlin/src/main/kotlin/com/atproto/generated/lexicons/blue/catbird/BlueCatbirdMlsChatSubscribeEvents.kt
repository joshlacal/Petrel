// Lexicon: 1, ID: blue.catbird.mlsChat.subscribeEvents
// Subscribe to live conversation events via WebSocket (consolidates subscribeConvoEvents with streamlined event types) Subscribe to live events (messages, membership changes, epoch advances, conversation updates) via firehose-style DAG-CBOR framing. Requires a valid ticket from getSubscriptionTicket.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatSubscribeEventsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.subscribeEvents"
}

    /**
     * A new encrypted message was sent
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMessageEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,        @SerialName("message")
        val message: BlueCatbirdMlsChatDefsMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMessageEvent"
        }
    }

    /**
     * A member joined the conversation (via Welcome, ExternalCommit, or re-addition)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMemberJoined(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member who joined */        @SerialName("did")
        val did: DID,/** Device ID if this was a device addition */        @SerialName("deviceId")
        val deviceId: String? = null,/** New epoch after join */        @SerialName("epoch")
        val epoch: Int,/** How the member joined */        @SerialName("method")
        val method: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMemberJoined"
        }
    }

    /**
     * A member left or was removed from the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMemberLeft(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member who left/was removed */        @SerialName("did")
        val did: DID,/** How the member departed */        @SerialName("action")
        val action: String,/** DID of the admin who removed (for removed/kicked) */        @SerialName("actor")
        val actor: DID? = null,/** Optional reason for removal */        @SerialName("reason")
        val reason: String? = null,/** New epoch after departure */        @SerialName("epoch")
        val epoch: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMemberLeft"
        }
    }

    /**
     * The MLS epoch advanced (group state change)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsEpochAdvanced(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** New epoch number */        @SerialName("epoch")
        val epoch: Int,/** Why the epoch advanced */        @SerialName("reason")
        val reason: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsEpochAdvanced"
        }
    }

    /**
     * Conversation metadata or policy was updated
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsConversationUpdated(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** List of fields that changed (e.g., 'name', 'policy', 'groupInfo') */        @SerialName("updatedFields")
        val updatedFields: List<String>? = null,/** DID of the member who made the update */        @SerialName("updatedBy")
        val updatedBy: DID? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsConversationUpdated"
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
        val resetBy: DID? = null,/** Optional reason for the reset */        @SerialName("reason")
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
     * A read receipt or read frontier update
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsReadEvent(
/** Resume cursor */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the reader */        @SerialName("did")
        val did: DID? = null,/** Message ID that was read up to */        @SerialName("messageId")
        val messageId: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReadEvent"
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
        val requestedBy: DID? = null    ) {
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
        val convoId: String,/** DID of the requester */        @SerialName("requestedBy")
        val requestedBy: DID? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent"
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
 * Subscribe to live conversation events via WebSocket (consolidates subscribeConvoEvents with streamlined event types) Subscribe to live events (messages, membership changes, epoch advances, conversation updates) via firehose-style DAG-CBOR framing. Requires a valid ticket from getSubscriptionTicket.
 *
 * Endpoint: blue.catbird.mlsChat.subscribeEvents
 */
fun ATProtoClient.Blue.Catbird.MlsChat.subscribeEvents(
parameters: BlueCatbirdMlsChatSubscribeEventsParameters): Flow<BlueCatbirdMlsChatSubscribeEventsMessage> = flow {
    val endpoint = "blue.catbird.mlsChat.subscribeEvents"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters.toQueryItems()

    // TODO: Implement WebSocket connection using a WebSocket library (e.g., Ktor WebSockets)
    // The implementation should:
    // 1. Establish WebSocket connection to endpoint with queryItems
    // 2. Listen for incoming messages
    // 3. Deserialize each message as BlueCatbirdMlsChatSubscribeEventsMessage
    // 4. Emit each message to the Flow
    // Example skeleton:
    // webSocketClient.connect(endpoint, queryItems) { message ->
    //     val decoded = Json.decodeFromString<BlueCatbirdMlsChatSubscribeEventsMessage>(message)
    //     emit(decoded)
    // }
    throw NotImplementedError("WebSocket subscription support requires a WebSocket client implementation")
}
