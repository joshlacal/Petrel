// Lexicon: 1, ID: com.atproto.server.listAppPasswords
// List all App Passwords.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerListapppasswords {
    const val TYPE_IDENTIFIER = "com.atproto.server.listAppPasswords"

        @Serializable
    data class Output(
        @SerialName("passwords")
        val passwords: List<Apppassword>    )

    sealed class Error(val name: String, val description: String?) {
        object Accounttakedown: Error("AccountTakedown", "")
    }

        @Serializable
    data class Apppassword(
        @SerialName("name")
        val name: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("privileged")
        val privileged: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#apppassword"
        }
    }

}

/**
 * List all App Passwords.
 *
 * Endpoint: com.atproto.server.listAppPasswords
 */
suspend fun ATProtoClient.Com.Atproto.Server.listapppasswords(
): ATProtoResponse<ComAtprotoServerListapppasswords.Output> {
    val endpoint = "com.atproto.server.listAppPasswords"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
