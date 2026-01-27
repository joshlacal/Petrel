// Lexicon: 1, ID: com.atproto.server.listAppPasswords
// List all App Passwords.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerListAppPasswordsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.listAppPasswords"
}

    @Serializable
    data class ComAtprotoServerListAppPasswordsAppPassword(
        @SerialName("name")
        val name: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("privileged")
        val privileged: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoServerListAppPasswordsAppPassword"
        }
    }

    @Serializable
    data class ComAtprotoServerListAppPasswordsOutput(
        @SerialName("passwords")
        val passwords: List<ComAtprotoServerListAppPasswordsAppPassword>    )

sealed class ComAtprotoServerListAppPasswordsError(val name: String, val description: String?) {
        object AccountTakedown: ComAtprotoServerListAppPasswordsError("AccountTakedown", "")
    }

/**
 * List all App Passwords.
 *
 * Endpoint: com.atproto.server.listAppPasswords
 */
suspend fun ATProtoClient.Com.Atproto.Server.listAppPasswords(
): ATProtoResponse<ComAtprotoServerListAppPasswordsOutput> {
    val endpoint = "com.atproto.server.listAppPasswords"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
