// Lexicon: 1, ID: blue.catbird.mlsChat.subscribeConvoEvents
// Firehose-style subscription for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via firehose-style DAG-CBOR framing in conversations involving the authenticated user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatSubscribeConvoEventsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.subscribeConvoEvents"
}

@Serializable
sealed interface BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion {
    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsMessageEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsMessageEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsMessageEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsReactionEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsReactionEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsReactionEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsTypingEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsTypingEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsTypingEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsInfoEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsInfoEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsInfoEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mlsChat.subscribeConvoEvents#BlueCatbirdMlsChatSubscribeConvoEventsReadEvent")
    data class BlueCatbirdMlsChatSubscribeConvoEventsReadEvent(val value: BlueCatbirdMlsChatSubscribeConvoEventsReadEvent) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion
}

    /**
     * Wrapper for stream events
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsEventWrapper(
/** The actual event (message, reaction, typing, info, newDevice, groupInfoRefreshRequested, or readditionRequested) */        @SerialName("event")
        val event: BlueCatbirdMlsChatSubscribeConvoEventsEventWrapperEventUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsEventWrapper"
        }
    }

    /**
     * Event for a newly sent message
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsMessageEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,        @SerialName("message")
        val message: BlueCatbirdMlsChatDefsMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsMessageEvent"
        }
    }

    /**
     * Event for a reaction added or removed
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsReactionEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** ID of the message that was reacted to */        @SerialName("messageId")
        val messageId: String,/** DID of the user who performed the reaction */        @SerialName("did")
        val did: DID,/** Reaction content (emoji or short code) */        @SerialName("reaction")
        val reaction: String,/** Action performed: 'add' or 'remove' */        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsReactionEvent"
        }
    }

    /**
     * Event indicating a user is typing
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsTypingEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the user typing */        @SerialName("did")
        val did: DID,/** True if the user started typing, false if they stopped */        @SerialName("isTyping")
        val isTyping: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsTypingEvent"
        }
    }

    /**
     * Event carrying informational messages (heartbeat or notices)
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsInfoEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Human-readable info or keep-alive message */        @SerialName("info")
        val info: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsInfoEvent"
        }
    }

    /**
     * Event indicating a user has registered a new device that needs to be added to the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base user DID (without device suffix) */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name */        @SerialName("deviceName")
        val deviceName: String?,/** Full device credential DID (format: did:plc:user#device-uuid) */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String,/** ID of the pending addition record for claim/complete flow */        @SerialName("pendingAdditionId")
        val pendingAdditionId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsNewDeviceEvent"
        }
    }

    /**
     * Event requesting active members to publish fresh GroupInfo for external commit joins
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member requesting the refresh (so they don't respond to their own request) */        @SerialName("requestedBy")
        val requestedBy: DID,/** ISO 8601 timestamp of when the refresh was requested */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsGroupInfoRefreshRequestedEvent"
        }
    }

    /**
     * Event indicating a member needs to be re-added to the conversation because both Welcome and External Commit failed
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the user requesting re-addition */        @SerialName("userDid")
        val userDid: DID,/** ISO 8601 timestamp of when re-addition was requested */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsReadditionRequestedEvent"
        }
    }

    /**
     * Event indicating a member joined, left, or was removed from the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the affected member */        @SerialName("did")
        val did: DID,/** Action performed: 'joined' (Welcome/ExternalCommit), 'left' (self), 'removed' or 'kicked' (by admin) */        @SerialName("action")
        val action: String,/** DID of the actor who performed the action (for removed/kicked) */        @SerialName("actor")
        val actor: DID?,/** Optional reason for removal */        @SerialName("reason")
        val reason: String?,/** New epoch after this change */        @SerialName("epoch")
        val epoch: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsMembershipChangeEvent"
        }
    }

    /**
     * Event indicating a member has read messages in the conversation
     */
    @Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsReadEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member who read the messages */        @SerialName("did")
        val did: DID,/** Optional specific message ID that was marked as read. If omitted, all messages were marked as read. */        @SerialName("messageId")
        val messageId: String?,/** ISO 8601 timestamp of when messages were read */        @SerialName("readAt")
        val readAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatSubscribeConvoEventsReadEvent"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatSubscribeConvoEventsParameters(
// Opaque resume cursor. If provided, resume after this position.        @SerialName("cursor")
        val cursor: String? = null,// Optional conversation filter (only receive events for this conversation).        @SerialName("convoId")
        val convoId: String? = null,// Authentication ticket from getSubscriptionTicket.        @SerialName("ticket")
        val ticket: String? = null    )

    @Serializable
    class BlueCatbirdMlsChatSubscribeConvoEventsMessage

/**
 * Firehose-style subscription for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via firehose-style DAG-CBOR framing in conversations involving the authenticated user
 *
 * Endpoint: blue.catbird.mlsChat.subscribeConvoEvents
 */
fun ATProtoClient.Blue.Catbird.MlsChat.subscribeConvoEvents(
parameters: BlueCatbirdMlsChatSubscribeConvoEventsParameters): Flow<BlueCatbirdMlsChatSubscribeConvoEventsMessage> = flow {
    val endpoint = "blue.catbird.mlsChat.subscribeConvoEvents"

    val queryParams = parameters.toQueryParams()

    // TODO: Implement WebSocket connection using a WebSocket library (e.g., Ktor WebSockets)
    // The implementation should:
    // 1. Establish WebSocket connection to endpoint with queryParams
    // 2. Listen for incoming messages
    // 3. Deserialize each message as BlueCatbirdMlsChatSubscribeConvoEventsMessage
    // 4. Emit each message to the Flow
    // Example skeleton:
    // webSocketClient.connect(endpoint, queryParams) { message ->
    //     val decoded = Json.decodeFromString<BlueCatbirdMlsChatSubscribeConvoEventsMessage>(message)
    //     emit(decoded)
    // }
    throw NotImplementedError("WebSocket subscription support requires a WebSocket client implementation")
}
