// Lexicon: 1, ID: com.atproto.admin.getSubjectStatus
// Get the service-specific admin status of a subject (account, record, or blob).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputSubjectUnion {
    @Serializable
    @SerialName("ComAtprotoAdminDefs.Reporef")
    data class Reporef(val value: ComAtprotoAdminDefs.Reporef) : OutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.getSubjectStatus#ComAtprotoRepoStrongref")
    data class ComAtprotoRepoStrongref(val value: ComAtprotoRepoStrongref) : OutputSubjectUnion

    @Serializable
    @SerialName("ComAtprotoAdminDefs.Repoblobref")
    data class Repoblobref(val value: ComAtprotoAdminDefs.Repoblobref) : OutputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputSubjectUnion
}

object ComAtprotoAdminGetsubjectstatus {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getSubjectStatus"

    @Serializable
    data class Parameters(
        @SerialName("did")
        val did: DID? = null,        @SerialName("uri")
        val uri: ATProtocolURI? = null,        @SerialName("blob")
        val blob: CID? = null    )

        @Serializable
    data class Output(
        @SerialName("subject")
        val subject: OutputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefs.Statusattr? = null,        @SerialName("deactivated")
        val deactivated: ComAtprotoAdminDefs.Statusattr? = null    )

}

/**
 * Get the service-specific admin status of a subject (account, record, or blob).
 *
 * Endpoint: com.atproto.admin.getSubjectStatus
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getsubjectstatus(
parameters: ComAtprotoAdminGetsubjectstatus.Parameters): ATProtoResponse<ComAtprotoAdminGetsubjectstatus.Output> {
    val endpoint = "com.atproto.admin.getSubjectStatus"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
