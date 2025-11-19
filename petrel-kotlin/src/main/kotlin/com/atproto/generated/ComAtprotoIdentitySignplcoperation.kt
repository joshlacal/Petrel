// Lexicon: 1, ID: com.atproto.identity.signPlcOperation
// Signs a PLC operation to update some value(s) in the requesting DID's document.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentitySignplcoperation {
    const val TYPE_IDENTIFIER = "com.atproto.identity.signPlcOperation"

    @Serializable
    data class Input(
// A token received through com.atproto.identity.requestPlcOperationSignature        @SerialName("token")
        val token: String? = null,        @SerialName("rotationKeys")
        val rotationKeys: List<String>? = null,        @SerialName("alsoKnownAs")
        val alsoKnownAs: List<String>? = null,        @SerialName("verificationMethods")
        val verificationMethods: JsonElement? = null,        @SerialName("services")
        val services: JsonElement? = null    )

        @Serializable
    data class Output(
// A signed DID PLC operation.        @SerialName("operation")
        val operation: JsonElement    )

}

/**
 * Signs a PLC operation to update some value(s) in the requesting DID's document.
 *
 * Endpoint: com.atproto.identity.signPlcOperation
 */
suspend fun ATProtoClient.Com.Atproto.Identity.signplcoperation(
input: ComAtprotoIdentitySignplcoperation.Input): ATProtoResponse<ComAtprotoIdentitySignplcoperation.Output> {
    val endpoint = "com.atproto.identity.signPlcOperation"

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
