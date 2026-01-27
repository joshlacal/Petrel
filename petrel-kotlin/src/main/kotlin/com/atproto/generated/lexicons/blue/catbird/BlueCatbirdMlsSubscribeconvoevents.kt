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
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : BlueCatbirdMlsSubscribeConvoEventsEventWrapperEventUnion
}

    /**
     * Wrapper for stream events
     */
    @Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsEventWrapper(
/** The actual event (message, reaction, typing, or info) */        @SerialName("event")
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

@Serializable
    data class BlueCatbirdMlsSubscribeConvoEventsParameters(
// Opaque resume cursor. If provided, resume after this position.        @SerialName("cursor")
        val cursor: String? = null,// Optional conversation filter (only receive events for this conversation).        @SerialName("convoId")
        val convoId: String? = null    )

    typealias BlueCatbirdMlsSubscribeConvoEventsOutput = BlueCatbirdMlsSubscribeConvoEventsEventWrapper

/**
 * Firehose-style subscription for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via firehose-style DAG-CBOR framing in conversations involving the authenticated user
 *
 * Endpoint: blue.catbird.mls.subscribeConvoEvents
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.subscribeConvoEvents(
parameters: BlueCatbirdMlsSubscribeConvoEventsParameters): ATProtoResponse<BlueCatbirdMlsSubscribeConvoEventsOutput> {
    val endpoint = "blue.catbird.mls.subscribeConvoEvents"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "text/event-stream"),
        body = null
    )
}
