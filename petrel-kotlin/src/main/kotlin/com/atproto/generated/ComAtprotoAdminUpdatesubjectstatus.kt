// Lexicon: 1, ID: com.atproto.admin.updateSubjectStatus
// Update the service-specific admin status of a subject (account, record, or blob).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface InputSubjectUnion {
    @Serializable
    @SerialName("ComAtprotoAdminDefs.Reporef")
    data class Reporef(val value: ComAtprotoAdminDefs.Reporef) : InputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoRepoStrongref")
    data class ComAtprotoRepoStrongref(val value: ComAtprotoRepoStrongref) : InputSubjectUnion

    @Serializable
    @SerialName("ComAtprotoAdminDefs.Repoblobref")
    data class Repoblobref(val value: ComAtprotoAdminDefs.Repoblobref) : InputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : InputSubjectUnion
}

@Serializable
sealed interface OutputSubjectUnion {
    @Serializable
    @SerialName("ComAtprotoAdminDefs.Reporef")
    data class Reporef(val value: ComAtprotoAdminDefs.Reporef) : OutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoRepoStrongref")
    data class ComAtprotoRepoStrongref(val value: ComAtprotoRepoStrongref) : OutputSubjectUnion

    @Serializable
    @SerialName("ComAtprotoAdminDefs.Repoblobref")
    data class Repoblobref(val value: ComAtprotoAdminDefs.Repoblobref) : OutputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputSubjectUnion
}

object ComAtprotoAdminUpdatesubjectstatus {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateSubjectStatus"

    @Serializable
    data class Input(
        @SerialName("subject")
        val subject: InputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefs.Statusattr? = null,        @SerialName("deactivated")
        val deactivated: ComAtprotoAdminDefs.Statusattr? = null    )

        @Serializable
    data class Output(
        @SerialName("subject")
        val subject: OutputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefs.Statusattr? = null    )

}

/**
 * Update the service-specific admin status of a subject (account, record, or blob).
 *
 * Endpoint: com.atproto.admin.updateSubjectStatus
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updatesubjectstatus(
input: ComAtprotoAdminUpdatesubjectstatus.Input): ATProtoResponse<ComAtprotoAdminUpdatesubjectstatus.Output> {
    val endpoint = "com.atproto.admin.updateSubjectStatus"

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
