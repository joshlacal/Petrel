// Lexicon: 1, ID: com.atproto.identity.signPlcOperation
// Signs a PLC operation to update some value(s) in the requesting DID's document.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoIdentitySignPlcOperationDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.signPlcOperation"
}

@Serializable
    data class ComAtprotoIdentitySignPlcOperationInput(
// A token received through com.atproto.identity.requestPlcOperationSignature        @SerialName("token")
        val token: String? = null,        @SerialName("rotationKeys")
        val rotationKeys: List<String>? = null,        @SerialName("alsoKnownAs")
        val alsoKnownAs: List<String>? = null,        @SerialName("verificationMethods")
        val verificationMethods: JsonElement? = null,        @SerialName("services")
        val services: JsonElement? = null    )

    @Serializable
    data class ComAtprotoIdentitySignPlcOperationOutput(
// A signed DID PLC operation.        @SerialName("operation")
        val operation: JsonElement    )

/**
 * Signs a PLC operation to update some value(s) in the requesting DID's document.
 *
 * Endpoint: com.atproto.identity.signPlcOperation
 */
suspend fun ATProtoClient.Com.Atproto.Identity.signPlcOperation(
input: ComAtprotoIdentitySignPlcOperationInput): ATProtoResponse<ComAtprotoIdentitySignPlcOperationOutput> {
    val endpoint = "com.atproto.identity.signPlcOperation"

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
