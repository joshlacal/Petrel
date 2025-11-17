// Lexicon: 1, ID: com.atproto.server.reserveSigningKey
// Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerReservesigningkey {
    const val TYPE_IDENTIFIER = "com.atproto.server.reserveSigningKey"

    @Serializable
    data class Input(
// The DID to reserve a key for.        @SerialName("did")
        val did: DID? = null    )

        @Serializable
    data class Output(
// The public key for the reserved signing key, in did:key serialization.        @SerialName("signingKey")
        val signingKey: String    )

}

/**
 * Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.
 *
 * Endpoint: com.atproto.server.reserveSigningKey
 */
suspend fun ATProtoClient.Com.Atproto.Server.reservesigningkey(
input: ComAtprotoServerReservesigningkey.Input): ATProtoResponse<ComAtprotoServerReservesigningkey.Output> {
    val endpoint = "com.atproto.server.reserveSigningKey"

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
