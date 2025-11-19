// Lexicon: 1, ID: com.atproto.server.deactivateAccount
// Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerDeactivateaccount {
    const val TYPE_IDENTIFIER = "com.atproto.server.deactivateAccount"

    @Serializable
    data class Input(
// A recommendation to server as to how long they should hold onto the deactivated account before deleting.        @SerialName("deleteAfter")
        val deleteAfter: ATProtocolDate? = null    )

}

/**
 * Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.
 *
 * Endpoint: com.atproto.server.deactivateAccount
 */
suspend fun ATProtoClient.Com.Atproto.Server.deactivateaccount(
input: ComAtprotoServerDeactivateaccount.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.deactivateAccount"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
