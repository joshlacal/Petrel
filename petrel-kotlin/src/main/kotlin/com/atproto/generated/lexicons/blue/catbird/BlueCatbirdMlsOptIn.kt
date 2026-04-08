// Lexicon: 1, ID: blue.catbird.mls.optIn
// Opt in to MLS chat. Creates private server-side record.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsOptInDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.optIn"
}

@Serializable
    data class BlueCatbirdMlsOptInInput(
// Device identifier for this opt-in        @SerialName("deviceId")
        val deviceId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsOptInOutput(
        @SerialName("optedIn")
        val optedIn: Boolean,        @SerialName("optedInAt")
        val optedInAt: ATProtocolDate    )

/**
 * Opt in to MLS chat. Creates private server-side record.
 *
 * Endpoint: blue.catbird.mls.optIn
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.optIn(
input: BlueCatbirdMlsOptInInput): ATProtoResponse<BlueCatbirdMlsOptInOutput> {
    val endpoint = "blue.catbird.mls.optIn"

    // JSON serialization
    val body = Json.encodeToString(input)
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
