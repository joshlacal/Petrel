// Lexicon: 1, ID: blue.catbird.mlsChat.getConvos
// Retrieve MLS conversations for the authenticated user with pagination support Query to fetch user's MLS conversations
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
        val cursor: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetConvosOutput(
// List of conversations        @SerialName("conversations")
        val conversations: List<BlueCatbirdMlsChatDefsConvoView>,// Pagination cursor for next page        @SerialName("cursor")
        val cursor: String? = null    )

sealed class BlueCatbirdMlsChatGetConvosError(val name: String, val description: String?) {
        object InvalidCursor: BlueCatbirdMlsChatGetConvosError("InvalidCursor", "The provided pagination cursor is invalid")
    }

/**
 * Retrieve MLS conversations for the authenticated user with pagination support Query to fetch user's MLS conversations
 *
 * Endpoint: blue.catbird.mlsChat.getConvos
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getConvos(
parameters: BlueCatbirdMlsChatGetConvosParameters): ATProtoResponse<BlueCatbirdMlsChatGetConvosOutput> {
    val endpoint = "blue.catbird.mlsChat.getConvos"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
