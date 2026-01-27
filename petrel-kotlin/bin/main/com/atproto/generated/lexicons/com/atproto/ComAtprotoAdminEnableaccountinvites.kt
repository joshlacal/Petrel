// Lexicon: 1, ID: com.atproto.admin.enableAccountInvites
// Re-enable an account's ability to receive invite codes.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminEnableAccountInvitesDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.enableAccountInvites"
}

@Serializable
    data class ComAtprotoAdminEnableAccountInvitesInput(
        @SerialName("account")
        val account: DID,// Optional reason for enabled invites.        @SerialName("note")
        val note: String? = null    )

/**
 * Re-enable an account's ability to receive invite codes.
 *
 * Endpoint: com.atproto.admin.enableAccountInvites
 */
suspend fun ATProtoClient.Com.Atproto.Admin.enableAccountInvites(
input: ComAtprotoAdminEnableAccountInvitesInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.admin.enableAccountInvites"

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
