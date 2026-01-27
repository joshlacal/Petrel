// Lexicon: 1, ID: com.atproto.server.reserveSigningKey
// Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerReserveSigningKeyDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.reserveSigningKey"
}

@Serializable
    data class ComAtprotoServerReserveSigningKeyInput(
// The DID to reserve a key for.        @SerialName("did")
        val did: DID? = null    )

    @Serializable
    data class ComAtprotoServerReserveSigningKeyOutput(
// The public key for the reserved signing key, in did:key serialization.        @SerialName("signingKey")
        val signingKey: String    )

/**
 * Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.
 *
 * Endpoint: com.atproto.server.reserveSigningKey
 */
suspend fun ATProtoClient.Com.Atproto.Server.reserveSigningKey(
input: ComAtprotoServerReserveSigningKeyInput): ATProtoResponse<ComAtprotoServerReserveSigningKeyOutput> {
    val endpoint = "com.atproto.server.reserveSigningKey"

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
