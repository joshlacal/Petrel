// Lexicon: 1, ID: com.atproto.admin.disableAccountInvites
// Disable an account from receiving new invite codes, but does not invalidate existing codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminDisableAccountInvitesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.disableAccountInvites"
}

@Serializable
    data class ComAtprotoAdminDisableAccountInvitesInput(
        @SerialName("account")
        val account: DID,// Optional reason for disabled invites.        @SerialName("note")
        val note: String? = null    )

/**
 * Disable an account from receiving new invite codes, but does not invalidate existing codes.
 *
 * Endpoint: com.atproto.admin.disableAccountInvites
 */
suspend fun ATProtoClient.Com.Atproto.Admin.disableAccountInvites(
input: ComAtprotoAdminDisableAccountInvitesInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.disableAccountInvites"

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
