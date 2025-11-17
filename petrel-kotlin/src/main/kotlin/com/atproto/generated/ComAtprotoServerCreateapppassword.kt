// Lexicon: 1, ID: com.atproto.server.createAppPassword
// Create an App Password.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerCreateapppassword {
    const val TYPE_IDENTIFIER = "com.atproto.server.createAppPassword"

    @Serializable
    data class Input(
// A short name for the App Password, to help distinguish them.        @SerialName("name")
        val name: String,// If an app password has 'privileged' access to possibly sensitive account state. Meant for use with trusted clients.        @SerialName("privileged")
        val privileged: Boolean? = null    )

        typealias Output = Apppassword

    sealed class Error(val name: String, val description: String?) {
        object Accounttakedown: Error("AccountTakedown", "")
    }

        @Serializable
    data class Apppassword(
        @SerialName("name")
        val name: String,        @SerialName("password")
        val password: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("privileged")
        val privileged: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#apppassword"
        }
    }

}

/**
 * Create an App Password.
 *
 * Endpoint: com.atproto.server.createAppPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.createapppassword(
input: ComAtprotoServerCreateapppassword.Input): ATProtoResponse<ComAtprotoServerCreateapppassword.Output> {
    val endpoint = "com.atproto.server.createAppPassword"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
