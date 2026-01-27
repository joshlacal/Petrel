// Lexicon: 1, ID: com.atproto.server.createAppPassword
// Create an App Password.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerCreateAppPasswordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.createAppPassword"
}

    @Serializable
    data class ComAtprotoServerCreateAppPasswordAppPassword(
        @SerialName("name")
        val name: String,        @SerialName("password")
        val password: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("privileged")
        val privileged: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoServerCreateAppPasswordAppPassword"
        }
    }

@Serializable
    data class ComAtprotoServerCreateAppPasswordInput(
// A short name for the App Password, to help distinguish them.        @SerialName("name")
        val name: String,// If an app password has 'privileged' access to possibly sensitive account state. Meant for use with trusted clients.        @SerialName("privileged")
        val privileged: Boolean? = null    )

    typealias ComAtprotoServerCreateAppPasswordOutput = ComAtprotoServerCreateAppPasswordAppPassword

sealed class ComAtprotoServerCreateAppPasswordError(val name: String, val description: String?) {
        object AccountTakedown: ComAtprotoServerCreateAppPasswordError("AccountTakedown", "")
    }

/**
 * Create an App Password.
 *
 * Endpoint: com.atproto.server.createAppPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.createAppPassword(
input: ComAtprotoServerCreateAppPasswordInput): ATProtoResponse<ComAtprotoServerCreateAppPasswordOutput> {
    val endpoint = "com.atproto.server.createAppPassword"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
