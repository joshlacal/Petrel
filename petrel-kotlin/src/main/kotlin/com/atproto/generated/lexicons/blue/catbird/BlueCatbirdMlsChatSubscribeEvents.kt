// Lexicon: 1, ID: blue.catbird.mlsChat.subscribeEvents
// Subscribe to live MLS conversation events via firehose-style streaming Subscribe to live events (messages, reactions, typing, membership changes, group resets, tree changes) via DAG-CBOR framing for conversations involving the authenticated user
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
     * Event for a newly sent message
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMessageEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,        @SerialName("message")
        val message: BlueCatbirdMlsChatDefsMessageView,/** True if this is an ephemeral message (not stored, SSE-only) */        @SerialName("ephemeral")
        val ephemeral: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMessageEvent"
        }
    }

    /**
     * Event for a reaction added or removed
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsReactionEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** ID of the message that was reacted to */        @SerialName("messageId")
        val messageId: String,/** DID of the user who performed the reaction */        @SerialName("did")
        val did: DID,/** Emoji content of the reaction */        @SerialName("emoji")
        val emoji: String,/** Action performed: 'add' or 'remove' */        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReactionEvent"
        }
    }

    /**
     * Event indicating a user is typing
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsTypingEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the user typing */        @SerialName("did")
        val did: DID,/** True if the user started typing, false if they stopped */        @SerialName("isTyping")
        val isTyping: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsTypingEvent"
        }
    }

    /**
     * Event carrying informational messages (heartbeat or notices)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsInfoEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Human-readable info or keep-alive message */        @SerialName("info")
        val info: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsInfoEvent"
        }
    }

    /**
     * Event indicating a user has registered a new device that needs to be added to the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsNewDeviceEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base user DID (without device suffix) */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name */        @SerialName("deviceName")
        val deviceName: String?,/** Full device credential DID (format: did:plc:user#device-uuid) */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String,/** ID of the pending addition record for claim/complete flow */        @SerialName("pendingAdditionId")
        val pendingAdditionId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsNewDeviceEvent"
        }
    }

    /**
     * Event requesting active members to publish fresh GroupInfo for external commit joins
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member requesting the refresh */        @SerialName("requestedBy")
        val requestedBy: DID,/** ISO 8601 timestamp of when the refresh was requested */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsGroupInfoRefreshRequestedEvent"
        }
    }

    /**
     * Event indicating a member needs to be re-added to the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the user requesting re-addition */        @SerialName("userDid")
        val userDid: DID,/** ISO 8601 timestamp of when re-addition was requested */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReadditionRequestedEvent"
        }
    }

    /**
     * Event indicating a member joined, left, or was removed from the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsMembershipChangeEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the affected member */        @SerialName("did")
        val did: DID,/** Action performed */        @SerialName("action")
        val action: String,/** DID of the actor who performed the action (for removed/kicked) */        @SerialName("actor")
        val actor: DID?,/** Optional reason for removal */        @SerialName("reason")
        val reason: String?,/** New epoch after this change */        @SerialName("epoch")
        val epoch: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsMembershipChangeEvent"
        }
    }

    /**
     * Event indicating a member has read messages in the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsReadEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member who read the messages */        @SerialName("did")
        val did: DID,/** Specific message ID marked as read. If omitted, all messages were marked as read. */        @SerialName("messageId")
        val messageId: String?,/** ISO 8601 timestamp of when messages were read */        @SerialName("readAt")
        val readAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsReadEvent"
        }
    }

    /**
     * Event indicating the MLS group has been reset (new group created to replace the old one)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsGroupResetEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** New MLS group ID after reset */        @SerialName("newGroupId")
        val newGroupId: String,/** Monotonically increasing reset generation counter */        @SerialName("resetGeneration")
        val resetGeneration: Int,/** DID of the member who initiated the reset */        @SerialName("resetBy")
        val resetBy: DID,/** Cipher suite of the new group */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Optional reason for the group reset */        @SerialName("reason")
        val reason: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsGroupResetEvent"
        }
    }

    /**
     * Event indicating the MLS ratchet tree has changed (commit processed)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeEventsTreeChangedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base64 encoded confirmation tag from the commit */        @SerialName("confirmationTag")
        val confirmationTag: String,/** New epoch after the tree change */        @SerialName("epoch")
        val epoch: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeEventsTreeChangedEvent"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatSubscribeEventsParameters(
// Authentication ticket from getSubscriptionTicket.        @SerialName("ticket")
        val ticket: String? = null,// Opaque resume cursor. If provided, resume after this position.        @SerialName("cursor")
        val cursor: String? = null,// Optional conversation filter (only receive events for these conversations).        @SerialName("convoIds")
        val convoIds: List<String>? = null    )

    @Serializable
    class BlueCatbirdMlsChatSubscribeEventsMessage

/**
 * Subscribe to live MLS conversation events via firehose-style streaming Subscribe to live events (messages, reactions, typing, membership changes, group resets, tree changes) via DAG-CBOR framing for conversations involving the authenticated user
 *
 * Endpoint: blue.catbird.mlsChat.subscribeEvents
 */
fun ATProtoClient.Blue.Catbird.MlsChat.subscribeEvents(
parameters: BlueCatbirdMlsChatSubscribeEventsParameters): Flow<BlueCatbirdMlsChatSubscribeEventsMessage> = flow {
    val endpoint = "blue.catbird.mlsChat.subscribeEvents"

    val queryParams = parameters.toQueryParams()

    // TODO: Implement WebSocket connection using a WebSocket library (e.g., Ktor WebSockets)
    // The implementation should:
    // 1. Establish WebSocket connection to endpoint with queryParams
    // 2. Listen for incoming messages
    // 3. Deserialize each message as BlueCatbirdMlsChatSubscribeEventsMessage
    // 4. Emit each message to the Flow
    // Example skeleton:
    // webSocketClient.connect(endpoint, queryParams) { message ->
    //     val decoded = Json.decodeFromString<BlueCatbirdMlsChatSubscribeEventsMessage>(message)
    //     emit(decoded)
    // }
    throw NotImplementedError("WebSocket subscription support requires a WebSocket client implementation")
}
