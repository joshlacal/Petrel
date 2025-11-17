// Lexicon: 1, ID: com.atproto.server.createAccount
// Create an account. Implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerCreateaccount {
    const val TYPE_IDENTIFIER = "com.atproto.server.createAccount"

    @Serializable
    data class Input(
        @SerialName("email")
        val email: String? = null,// Requested handle for the account.        @SerialName("handle")
        val handle: Handle,// Pre-existing atproto DID, being imported to a new account.        @SerialName("did")
        val did: DID? = null,        @SerialName("inviteCode")
        val inviteCode: String? = null,        @SerialName("verificationCode")
        val verificationCode: String? = null,        @SerialName("verificationPhone")
        val verificationPhone: String? = null,// Initial account password. May need to meet instance-specific password strength requirements.        @SerialName("password")
        val password: String? = null,// DID PLC rotation key (aka, recovery key) to be included in PLC creation operation.        @SerialName("recoveryKey")
        val recoveryKey: String? = null,// A signed DID PLC operation to be submitted as part of importing an existing account to this instance. NOTE: this optional field may be updated when full account migration is implemented.        @SerialName("plcOp")
        val plcOp: JsonElement? = null    )

        @Serializable
    data class Output(
        @SerialName("accessJwt")
        val accessJwt: String,        @SerialName("refreshJwt")
        val refreshJwt: String,        @SerialName("handle")
        val handle: Handle,// The DID of the new account.        @SerialName("did")
        val did: DID,// Complete DID document.        @SerialName("didDoc")
        val didDoc: JsonElement? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Invalidhandle: Error("InvalidHandle", "")
        object Invalidpassword: Error("InvalidPassword", "")
        object Invalidinvitecode: Error("InvalidInviteCode", "")
        object Handlenotavailable: Error("HandleNotAvailable", "")
        object Unsupporteddomain: Error("UnsupportedDomain", "")
        object Unresolvabledid: Error("UnresolvableDid", "")
        object Incompatiblediddoc: Error("IncompatibleDidDoc", "")
    }

}

/**
 * Create an account. Implemented by PDS.
 *
 * Endpoint: com.atproto.server.createAccount
 */
suspend fun ATProtoClient.Com.Atproto.Server.createaccount(
input: ComAtprotoServerCreateaccount.Input): ATProtoResponse<ComAtprotoServerCreateaccount.Output> {
    val endpoint = "com.atproto.server.createAccount"

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
