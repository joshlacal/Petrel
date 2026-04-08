// Lexicon: 1, ID: blue.catbird.mlsChat.getOptInStatus
// Check if users have opted into MLS chat Query opt-in status for a list of users. Returns array of status objects with DID, opt-in boolean, and optional timestamp.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetOptInStatusDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getOptInStatus"
}

    @Serializable
    data class BlueCatbirdMlsChatGetOptInStatusOptInStatus(
/** User DID */        @SerialName("did")
        val did: DID,/** Whether user has opted into MLS */        @SerialName("optedIn")
        val optedIn: Boolean,/** When user opted in (if applicable) */        @SerialName("optedInAt")
        val optedInAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetOptInStatusOptInStatus"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetOptInStatusParameters(
// List of DIDs to check (max 100)        @SerialName("dids")
        val dids: List<DID>    )

    @Serializable
    data class BlueCatbirdMlsChatGetOptInStatusOutput(
        @SerialName("statuses")
        val statuses: List<BlueCatbirdMlsChatGetOptInStatusOptInStatus>    )

/**
 * Check if users have opted into MLS chat Query opt-in status for a list of users. Returns array of status objects with DID, opt-in boolean, and optional timestamp.
 *
 * Endpoint: blue.catbird.mlsChat.getOptInStatus
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getOptInStatus(
parameters: BlueCatbirdMlsChatGetOptInStatusParameters): ATProtoResponse<BlueCatbirdMlsChatGetOptInStatusOutput> {
    val endpoint = "blue.catbird.mlsChat.getOptInStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
