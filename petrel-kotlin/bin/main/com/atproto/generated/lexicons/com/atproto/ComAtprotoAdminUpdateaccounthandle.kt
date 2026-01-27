// Lexicon: 1, ID: com.atproto.admin.updateAccountHandle
// Administrative action to update an account's handle.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminUpdateAccountHandleDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateAccountHandle"
}

@Serializable
    data class ComAtprotoAdminUpdateAccountHandleInput(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle    )

/**
 * Administrative action to update an account's handle.
 *
 * Endpoint: com.atproto.admin.updateAccountHandle
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateAccountHandle(
input: ComAtprotoAdminUpdateAccountHandleInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.updateAccountHandle"

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
