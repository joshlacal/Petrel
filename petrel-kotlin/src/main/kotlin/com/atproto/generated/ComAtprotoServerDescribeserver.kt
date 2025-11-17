// Lexicon: 1, ID: com.atproto.server.describeServer
// Describes the server's account creation requirements and capabilities. Implemented by PDS.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerDescribeserver {
    const val TYPE_IDENTIFIER = "com.atproto.server.describeServer"

        @Serializable
    data class Output(
// If true, an invite code must be supplied to create an account on this instance.        @SerialName("inviteCodeRequired")
        val inviteCodeRequired: Boolean? = null,// If true, a phone verification token must be supplied to create an account on this instance.        @SerialName("phoneVerificationRequired")
        val phoneVerificationRequired: Boolean? = null,// List of domain suffixes that can be used in account handles.        @SerialName("availableUserDomains")
        val availableUserDomains: List<String>,// URLs of service policy documents.        @SerialName("links")
        val links: Links? = null,// Contact information        @SerialName("contact")
        val contact: Contact? = null,        @SerialName("did")
        val did: DID    )

        @Serializable
    data class Links(
        @SerialName("privacyPolicy")
        val privacyPolicy: URI?,        @SerialName("termsOfService")
        val termsOfService: URI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#links"
        }
    }

    @Serializable
    data class Contact(
        @SerialName("email")
        val email: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#contact"
        }
    }

}

/**
 * Describes the server's account creation requirements and capabilities. Implemented by PDS.
 *
 * Endpoint: com.atproto.server.describeServer
 */
suspend fun ATProtoClient.Com.Atproto.Server.describeserver(
): ATProtoResponse<ComAtprotoServerDescribeserver.Output> {
    val endpoint = "com.atproto.server.describeServer"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
