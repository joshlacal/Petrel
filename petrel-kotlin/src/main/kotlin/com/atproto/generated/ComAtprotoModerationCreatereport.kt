// Lexicon: 1, ID: com.atproto.moderation.createReport
// Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface InputSubjectUnion {
    @Serializable
    @SerialName("ComAtprotoAdminDefs.Reporef")
    data class Reporef(val value: ComAtprotoAdminDefs.Reporef) : InputSubjectUnion

    @Serializable
    @SerialName("com.atproto.moderation.createReport#ComAtprotoRepoStrongref")
    data class ComAtprotoRepoStrongref(val value: ComAtprotoRepoStrongref) : InputSubjectUnion

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
    @SerialName("com.atproto.moderation.createReport#ComAtprotoRepoStrongref")
    data class ComAtprotoRepoStrongref(val value: ComAtprotoRepoStrongref) : OutputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputSubjectUnion
}

object ComAtprotoModerationCreatereport {
    const val TYPE_IDENTIFIER = "com.atproto.moderation.createReport"

    @Serializable
    data class Input(
// Indicates the broad category of violation the report is for.        @SerialName("reasonType")
        val reasonType: ComAtprotoModerationDefs.Reasontype,// Additional context about the content and violation.        @SerialName("reason")
        val reason: String? = null,        @SerialName("subject")
        val subject: InputSubjectUnion,        @SerialName("modTool")
        val modTool: Modtool? = null    )

        @Serializable
    data class Output(
        @SerialName("id")
        val id: Int,        @SerialName("reasonType")
        val reasonType: ComAtprotoModerationDefs.Reasontype,        @SerialName("reason")
        val reason: String? = null,        @SerialName("subject")
        val subject: OutputSubjectUnion,        @SerialName("reportedBy")
        val reportedBy: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    )

        /**
     * Moderation tool information for tracing the source of the action
     */
    @Serializable
    data class Modtool(
/** Name/identifier of the source (e.g., 'bsky-app/android', 'bsky-web/chrome') */        @SerialName("name")
        val name: String,/** Additional arbitrary metadata about the source */        @SerialName("meta")
        val meta: JsonElement?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#modtool"
        }
    }

}

/**
 * Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
 *
 * Endpoint: com.atproto.moderation.createReport
 */
suspend fun ATProtoClient.Com.Atproto.Moderation.createreport(
input: ComAtprotoModerationCreatereport.Input): ATProtoResponse<ComAtprotoModerationCreatereport.Output> {
    val endpoint = "com.atproto.moderation.createReport"

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
