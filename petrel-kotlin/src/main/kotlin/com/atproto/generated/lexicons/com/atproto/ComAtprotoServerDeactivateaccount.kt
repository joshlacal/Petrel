// Lexicon: 1, ID: com.atproto.server.deactivateAccount
// Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerDeactivateAccountDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.deactivateAccount"
}

@Serializable
    data class ComAtprotoServerDeactivateAccountInput(
// A recommendation to server as to how long they should hold onto the deactivated account before deleting.        @SerialName("deleteAfter")
        val deleteAfter: ATProtocolDate? = null    )

/**
 * Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.
 *
 * Endpoint: com.atproto.server.deactivateAccount
 */
suspend fun ATProtoClient.Com.Atproto.Server.deactivateAccount(
input: ComAtprotoServerDeactivateAccountInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.deactivateAccount"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
