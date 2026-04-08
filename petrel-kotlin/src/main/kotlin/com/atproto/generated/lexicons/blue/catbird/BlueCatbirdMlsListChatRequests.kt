// Lexicon: 1, ID: blue.catbird.mls.listChatRequests
// List pending chat requests received by the authenticated user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsListChatRequestsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.listChatRequests"
}

    @Serializable
    data class BlueCatbirdMlsListChatRequestsChatRequest(
/** Request ID (ULID) */        @SerialName("id")
        val id: String,/** DID of the sender */        @SerialName("senderDid")
        val senderDid: String,/** Current request status */        @SerialName("status")
        val status: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate,/** Optional preview text from sender */        @SerialName("previewText")
        val previewText: String?,/** Number of held messages */        @SerialName("messageCount")
        val messageCount: Int?,/** If true, this is a group invite */        @SerialName("isGroupInvite")
        val isGroupInvite: Boolean?,/** Group conversation ID if group invite */        @SerialName("groupId")
        val groupId: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsListChatRequestsChatRequest"
        }
    }

@Serializable
    data class BlueCatbirdMlsListChatRequestsParameters(
// Pagination cursor (request ID)        @SerialName("cursor")
        val cursor: String? = null,// Number of requests to return        @SerialName("limit")
        val limit: Int? = null,// Filter by request status (default: pending only)        @SerialName("status")
        val status: String? = null    )

    @Serializable
    data class BlueCatbirdMlsListChatRequestsOutput(
        @SerialName("requests")
        val requests: List<BlueCatbirdMlsListChatRequestsChatRequest>,// Pagination cursor for next page        @SerialName("cursor")
        val cursor: String? = null    )

/**
 * List pending chat requests received by the authenticated user
 *
 * Endpoint: blue.catbird.mls.listChatRequests
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.listChatRequests(
parameters: BlueCatbirdMlsListChatRequestsParameters): ATProtoResponse<BlueCatbirdMlsListChatRequestsOutput> {
    val endpoint = "blue.catbird.mls.listChatRequests"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
