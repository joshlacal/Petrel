// Lexicon: 1, ID: blue.catbird.mls.getOptInStatus
// Check if users have opted into MLS chat Query opt-in status for a list of users. Returns array of status objects with DID, opt-in boolean, and optional timestamp.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetOptInStatusDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getOptInStatus"
}

    @Serializable
    data class BlueCatbirdMlsGetOptInStatusOptInStatus(
/** User DID */        @SerialName("did")
        val did: DID,/** Whether user has opted into MLS */        @SerialName("optedIn")
        val optedIn: Boolean,/** When user opted in (if applicable) */        @SerialName("optedInAt")
        val optedInAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetOptInStatusOptInStatus"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetOptInStatusParameters(
// List of DIDs to check (max 100)        @SerialName("dids")
        val dids: List<DID>    )

    @Serializable
    data class BlueCatbirdMlsGetOptInStatusOutput(
        @SerialName("statuses")
        val statuses: List<BlueCatbirdMlsGetOptInStatusOptInStatus>    )

/**
 * Check if users have opted into MLS chat Query opt-in status for a list of users. Returns array of status objects with DID, opt-in boolean, and optional timestamp.
 *
 * Endpoint: blue.catbird.mls.getOptInStatus
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getOptInStatus(
parameters: BlueCatbirdMlsGetOptInStatusParameters): ATProtoResponse<BlueCatbirdMlsGetOptInStatusOutput> {
    val endpoint = "blue.catbird.mls.getOptInStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
