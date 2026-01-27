// Lexicon: 1, ID: com.atproto.admin.deleteAccount
// Delete a user account as an administrator.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminDeleteAccountDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.deleteAccount"
}

@Serializable
    data class ComAtprotoAdminDeleteAccountInput(
        @SerialName("did")
        val did: DID    )

/**
 * Delete a user account as an administrator.
 *
 * Endpoint: com.atproto.admin.deleteAccount
 */
suspend fun ATProtoClient.Com.Atproto.Admin.deleteAccount(
input: ComAtprotoAdminDeleteAccountInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.deleteAccount"

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
