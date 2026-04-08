// Lexicon: 1, ID: blue.catbird.mls.subscribeConvoEvents
// Firehose-style subscription for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via firehose-style DAG-CBOR framing in conversations involving the authenticated user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsSubscribeConvoEventsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.subscribeConvoEvents"
}

@Serializable
sealed interface BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion {
    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsMessageEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsMessageEvent(val value: BlueCatbirdMlsSubscribeConvoEventsMessageEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsReactionEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsReactionEvent(val value: BlueCatbirdMlsSubscribeConvoEventsReactionEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsTypingEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsTypingEvent(val value: BlueCatbirdMlsSubscribeConvoEventsTypingEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsInfoEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsInfoEvent(val value: BlueCatbirdMlsSubscribeConvoEventsInfoEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsNewDeviceEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsNewDeviceEvent(val value: BlueCatbirdMlsSubscribeConvoEventsNewDeviceEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsGroupInfoRefreshRequestedEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsGroupInfoRefreshRequestedEvent(val value: BlueCatbirdMlsSubscribeConvoEventsGroupInfoRefreshRequestedEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsReadditionRequestedEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsReadditionRequestedEvent(val value: BlueCatbirdMlsSubscribeConvoEventsReadditionRequestedEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsMembershipChangeEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsMembershipChangeEvent(val value: BlueCatbirdMlsSubscribeConvoEventsMembershipChangeEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("blue.catbird.mls.subscribeConvoEvents#BlueCatbirdMlsSubscribeConvoEventsReadEvent")
    data class BlueCatbirdMlsSubscribeConvoEventsReadEvent(val value: BlueCatbirdMlsSubscribeConvoEventsReadEvent) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion
}

    /**
     * Wrapper for stream events
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsEventWrapper(
/** The actual event (message, reaction, typing, info, newDevice, groupInfoRefreshRequested, or readditionRequested) */        @SerialName("event")
        val event: BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsEventWrapper"
        }
    }

    /**
     * Event for a newly sent message
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsMessageEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,        @SerialName("message")
        val message: BlueCatbirdMlsDefsMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsMessageEvent"
        }
    }

    /**
     * Event for a reaction added or removed
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsReactionEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** ID of the message that was reacted to */        @SerialName("messageId")
        val messageId: String,/** DID of the user who performed the reaction */        @SerialName("did")
        val did: DID,/** Reaction content (emoji or short code) */        @SerialName("reaction")
        val reaction: String,/** Action performed: 'add' or 'remove' */        @SerialName("action")
        val action: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsReactionEvent"
        }
    }

    /**
     * Event indicating a user is typing
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsTypingEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the user typing */        @SerialName("did")
        val did: DID,/** True if the user started typing, false if they stopped */        @SerialName("isTyping")
        val isTyping: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsTypingEvent"
        }
    }

    /**
     * Event carrying informational messages (heartbeat or notices)
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsInfoEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Human-readable info or keep-alive message */        @SerialName("info")
        val info: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsInfoEvent"
        }
    }

    /**
     * Event indicating a user has registered a new device that needs to be added to the conversation
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsNewDeviceEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base user DID (without device suffix) */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name */        @SerialName("deviceName")
        val deviceName: String?,/** Full device credential DID (format: did:plc:user#device-uuid) */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String,/** ID of the pending addition record for claim/complete flow */        @SerialName("pendingAdditionId")
        val pendingAdditionId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsNewDeviceEvent"
        }
    }

    /**
     * Event requesting active members to publish fresh GroupInfo for external commit joins
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsGroupInfoRefreshRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member requesting the refresh (so they don't respond to their own request) */        @SerialName("requestedBy")
        val requestedBy: DID,/** ISO 8601 timestamp of when the refresh was requested */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsGroupInfoRefreshRequestedEvent"
        }
    }

    /**
     * Event indicating a member needs to be re-added to the conversation because both Welcome and External Commit failed
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsReadditionRequestedEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the user requesting re-addition */        @SerialName("userDid")
        val userDid: DID,/** ISO 8601 timestamp of when re-addition was requested */        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsReadditionRequestedEvent"
        }
    }

    /**
     * Event indicating a member joined, left, or was removed from the conversation
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsMembershipChangeEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the affected member */        @SerialName("did")
        val did: DID,/** Action performed: 'joined' (Welcome/ExternalCommit), 'left' (self), 'removed' or 'kicked' (by admin) */        @SerialName("action")
        val action: String,/** DID of the actor who performed the action (for removed/kicked) */        @SerialName("actor")
        val actor: DID?,/** Optional reason for removal */        @SerialName("reason")
        val reason: String?,/** New epoch after this change */        @SerialName("epoch")
        val epoch: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsMembershipChangeEvent"
        }
    }

    /**
     * Event indicating a member has read messages in the conversation
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsReadEvent(
/** Resume cursor for this event position */        @SerialName("cursor")
        val cursor: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of the member who read the messages */        @SerialName("did")
        val did: DID,/** Optional specific message ID that was marked as read. If omitted, all messages were marked as read. */        @SerialName("messageId")
        val messageId: String?,/** ISO 8601 timestamp of when messages were read */        @SerialName("readAt")
        val readAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsSubscribeConvoEventsReadEvent"
        }
    }

@Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsParameters(
// Opaque resume cursor. If provided, resume after this position.        @SerialName("cursor")
        val cursor: String? = null,// Optional conversation filter (only receive events for this conversation).        @SerialName("convoId")
        val convoId: String? = null,// Authentication ticket from getSubscriptionTicket.        @SerialName("ticket")
        val ticket: String? = null    )

    @Serializable
    class BlueCatbirdMlsSubscribeConvoEventsMessage

/**
 * Firehose-style subscription for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via firehose-style DAG-CBOR framing in conversations involving the authenticated user
 *
 * Endpoint: blue.catbird.mls.subscribeConvoEvents
 */
fun ATProtoClient.Blue.Catbird.Mls.subscribeConvoEvents(
parameters: BlueCatbirdMlsSubscribeConvoEventsParameters): Flow<BlueCatbirdMlsSubscribeConvoEventsMessage> = flow {
    val endpoint = "blue.catbird.mls.subscribeConvoEvents"

    val queryParams = parameters.toQueryParams()

    // TODO: Implement WebSocket connection using a WebSocket library (e.g., Ktor WebSockets)
    // The implementation should:
    // 1. Establish WebSocket connection to endpoint with queryParams
    // 2. Listen for incoming messages
    // 3. Deserialize each message as BlueCatbirdMlsSubscribeConvoEventsMessage
    // 4. Emit each message to the Flow
    // Example skeleton:
    // webSocketClient.connect(endpoint, queryParams) { message ->
    //     val decoded = Json.decodeFromString<BlueCatbirdMlsSubscribeConvoEventsMessage>(message)
    //     emit(decoded)
    // }
    throw NotImplementedError("WebSocket subscription support requires a WebSocket client implementation")
}
