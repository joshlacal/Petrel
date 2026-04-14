// Lexicon: 1, ID: blue.catbird.mlsChat.getConvos
// Retrieve conversations with flexible filtering (consolidates getConvos + getExpectedConversations + listChatRequests + getRequestCount) Query conversations for the authenticated user with pagination and filtering. The 'filter' parameter replaces separate endpoints for expected conversations, chat requests, and request counts.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetConvosDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getConvos"
}

@Serializable
    data class BlueCatbirdMlsChatGetConvosParameters(
// Maximum number of conversations to return        @SerialName("limit")
        val limit: Int? = null,// Pagination cursor from previous response        @SerialName("cursor")
        val cursor: String? = null,// Filter conversations: 'all' (default, active conversations), 'pending' (incoming chat requests awaiting acceptance), 'expected' (conversations user is expected to join via Welcome/ExternalCommit)        @SerialName("filter")
        val filter: String? = null,// If true, only return counts without conversation data. Useful for badge counts.        @SerialName("countOnly")
        val countOnly: Boolean? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetConvosOutput(
// List of conversations (empty if countOnly is true)        @SerialName("conversations")
        val conversations: List<BlueCatbirdMlsChatDefsConvoView>,// Pagination cursor for next page        @SerialName("cursor")
        val cursor: String? = null,// Number of pending chat requests (always included for badge display)        @SerialName("pendingCount")
        val pendingCount: Int? = null,// Total number of unresolved chat requests        @SerialName("requestCount")
        val requestCount: Int? = null    )

sealed class BlueCatbirdMlsChatGetConvosError(val name: String, val description: String?) {
        object InvalidCursor: BlueCatbirdMlsChatGetConvosError("InvalidCursor", "The provided pagination cursor is invalid")
        object InvalidFilter: BlueCatbirdMlsChatGetConvosError("InvalidFilter", "Unknown filter value")
    }

/**
 * Retrieve conversations with flexible filtering (consolidates getConvos + getExpectedConversations + listChatRequests + getRequestCount) Query conversations for the authenticated user with pagination and filtering. The 'filter' parameter replaces separate endpoints for expected conversations, chat requests, and request counts.
 *
 * Endpoint: blue.catbird.mlsChat.getConvos
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getConvos(
parameters: BlueCatbirdMlsChatGetConvosParameters): ATProtoResponse<BlueCatbirdMlsChatGetConvosOutput> {
    val endpoint = "blue.catbird.mlsChat.getConvos"

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
