// Lexicon: 1, ID: blue.catbird.mls.getConvos
// Retrieve MLS conversations for the authenticated user with pagination support Query to fetch user's MLS conversations
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetConvosDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getConvos"
}

@Serializable
    data class BlueCatbirdMlsGetConvosParameters(
// Maximum number of conversations to return        @SerialName("limit")
        val limit: Int? = null,// Pagination cursor from previous response        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetConvosOutput(
// List of conversations        @SerialName("conversations")
        val conversations: List<BlueCatbirdMlsDefsConvoView>,// Pagination cursor for next page        @SerialName("cursor")
        val cursor: String? = null    )

sealed class BlueCatbirdMlsGetConvosError(val name: String, val description: String?) {
        object InvalidCursor: BlueCatbirdMlsGetConvosError("InvalidCursor", "The provided pagination cursor is invalid")
    }

/**
 * Retrieve MLS conversations for the authenticated user with pagination support Query to fetch user's MLS conversations
 *
 * Endpoint: blue.catbird.mls.getConvos
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getConvos(
parameters: BlueCatbirdMlsGetConvosParameters): ATProtoResponse<BlueCatbirdMlsGetConvosOutput> {
    val endpoint = "blue.catbird.mls.getConvos"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
