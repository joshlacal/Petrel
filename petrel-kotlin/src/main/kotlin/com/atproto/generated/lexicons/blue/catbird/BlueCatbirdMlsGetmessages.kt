// Lexicon: 1, ID: blue.catbird.mls.getMessages
// Retrieve messages from an MLS conversation. Messages are GUARANTEED to be returned in MLS sequential order (epoch ASC, seq ASC). Clients MUST process messages in this order for proper MLS decryption.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetMessagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getMessages"
}

    /**
     * Metadata about missing sequence numbers in a conversation. Gaps can occur when members are removed from the conversation.
     */
    @Serializable
    data class BlueCatbirdMlsGetMessagesGapInfo(
/** Whether there are gaps in the sequence number range */        @SerialName("hasGaps")
        val hasGaps: Boolean,/** Array of missing sequence numbers within the conversation's min-max seq range. Empty if hasGaps is false. */        @SerialName("missingSeqs")
        val missingSeqs: List<Int>,/** Total number of messages in the conversation (including gaps) */        @SerialName("totalMessages")
        val totalMessages: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetMessagesGapInfo"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetMessagesParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Maximum number of messages to return        @SerialName("limit")
        val limit: Int? = null,// Fetch messages with seq > sinceSeq (pagination cursor). Use lastSeq from previous response.        @SerialName("sinceSeq")
        val sinceSeq: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsGetMessagesOutput(
// Messages in MLS sequential order (epoch ASC, seq ASC). Clients MUST process in this order.        @SerialName("messages")
        val messages: List<BlueCatbirdMlsDefsMessageView>,// Sequence number of the last message in this response. Use as sinceSeq for next page. Omitted if no messages returned.        @SerialName("lastSeq")
        val lastSeq: Int? = null,// Gap detection metadata for missing messages. Omitted if no gaps detected or conversation is empty.        @SerialName("gapInfo")
        val gapInfo: BlueCatbirdMlsGetMessagesGapInfo? = null    )

sealed class BlueCatbirdMlsGetMessagesError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsGetMessagesError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsGetMessagesError("NotMember", "Caller is not a member of the conversation")
        object InvalidCursor: BlueCatbirdMlsGetMessagesError("InvalidCursor", "sinceSeq parameter is invalid or exceeds available messages")
    }

/**
 * Retrieve messages from an MLS conversation. Messages are GUARANTEED to be returned in MLS sequential order (epoch ASC, seq ASC). Clients MUST process messages in this order for proper MLS decryption.
 *
 * Endpoint: blue.catbird.mls.getMessages
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getMessages(
parameters: BlueCatbirdMlsGetMessagesParameters): ATProtoResponse<BlueCatbirdMlsGetMessagesOutput> {
    val endpoint = "blue.catbird.mls.getMessages"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
