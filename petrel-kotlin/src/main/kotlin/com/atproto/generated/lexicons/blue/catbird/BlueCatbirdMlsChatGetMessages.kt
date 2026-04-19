// Lexicon: 1, ID: blue.catbird.mlsChat.getMessages
// Retrieve messages from a conversation with type filtering (consolidates getMessages + getCommits) Retrieve messages from an MLS conversation. Messages are GUARANTEED to be returned in MLS sequential order (epoch ASC, seq ASC). Clients MUST process messages in this order for proper MLS decryption. The 'type' filter replaces the separate getCommits endpoint.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetMessagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getMessages"
}

    @Serializable
    data class BlueCatbirdMlsChatGetMessagesGapInfo(
/** Whether there are gaps in the sequence number range */        @SerialName("hasGaps")
        val hasGaps: Boolean,/** Array of missing sequence numbers */        @SerialName("missingSeqs")
        val missingSeqs: List<Int>,/** Total number of messages in the conversation */        @SerialName("totalMessages")
        val totalMessages: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetMessagesGapInfo"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetMessagesParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Maximum number of messages to return        @SerialName("limit")
        val limit: Int? = null,// Fetch messages with seq > sinceSeq (pagination cursor)        @SerialName("sinceSeq")
        val sinceSeq: Int? = null,// Filter by message type: 'app' for user content only, 'commit' for MLS protocol control messages only, 'all' for both        @SerialName("type")
        val type: String? = null,// Lower bound (inclusive) on MLS epoch. Only honored for type='commit' or type='all' — narrows the commit-catchup range so LIMIT reaches the commits a lagging client actually needs. Defaults to 0 (start of history) when omitted.        @SerialName("fromEpoch")
        val fromEpoch: Int? = null,// Upper bound (inclusive) on MLS epoch. Only honored for type='commit' or type='all'. Defaults to the conversation's current_epoch when omitted.        @SerialName("toEpoch")
        val toEpoch: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetMessagesOutput(
// Messages in MLS sequential order (epoch ASC, seq ASC)        @SerialName("messages")
        val messages: List<BlueCatbirdMlsChatDefsMessageView>,// Sequence number of the last message in this response. Use as sinceSeq for next page.        @SerialName("lastSeq")
        val lastSeq: Int? = null,// Gap detection metadata for missing messages        @SerialName("gapInfo")
        val gapInfo: BlueCatbirdMlsChatGetMessagesGapInfo? = null    )

sealed class BlueCatbirdMlsChatGetMessagesError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetMessagesError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatGetMessagesError("NotMember", "Caller is not a member of the conversation")
        object InvalidCursor: BlueCatbirdMlsChatGetMessagesError("InvalidCursor", "sinceSeq parameter is invalid or exceeds available messages")
    }

/**
 * Retrieve messages from a conversation with type filtering (consolidates getMessages + getCommits) Retrieve messages from an MLS conversation. Messages are GUARANTEED to be returned in MLS sequential order (epoch ASC, seq ASC). Clients MUST process messages in this order for proper MLS decryption. The 'type' filter replaces the separate getCommits endpoint.
 *
 * Endpoint: blue.catbird.mlsChat.getMessages
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getMessages(
parameters: BlueCatbirdMlsChatGetMessagesParameters): ATProtoResponse<BlueCatbirdMlsChatGetMessagesOutput> {
    val endpoint = "blue.catbird.mlsChat.getMessages"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
