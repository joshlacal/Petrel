// Lexicon: 1, ID: blue.catbird.mlsChat.optOut
// Opt out of MLS chat. Removes server-side opt-in record.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatOptOutDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.optOut"
}

    @Serializable
    data class BlueCatbirdMlsChatOptOutOutput(
        @SerialName("success")
        val success: Boolean    )

/**
 * Opt out of MLS chat. Removes server-side opt-in record.
 *
 * Endpoint: blue.catbird.mlsChat.optOut
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.optOut(
): ATProtoResponse<BlueCatbirdMlsChatOptOutOutput> {
    val endpoint = "blue.catbird.mlsChat.optOut"

    val body: String? = null
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
