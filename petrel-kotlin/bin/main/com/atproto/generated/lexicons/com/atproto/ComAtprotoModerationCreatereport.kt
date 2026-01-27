// Lexicon: 1, ID: com.atproto.moderation.createReport
// Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoModerationCreateReportDefs {
    const val TYPE_IDENTIFIER = "com.atproto.moderation.createReport"
}

@Serializable
sealed interface ComAtprotoModerationCreateReportInputSubjectUnion {
    @Serializable
    @SerialName("com.atproto.moderation.createReport#ComAtprotoAdminDefsRepoRef")
    data class ComAtprotoAdminDefsRepoRef(val value: ComAtprotoAdminDefsRepoRef) : ComAtprotoModerationCreateReportInputSubjectUnion

    @Serializable
    @SerialName("com.atproto.moderation.createReport#ComAtprotoRepoStrongRef")
    data class ComAtprotoRepoStrongRef(val value: ComAtprotoRepoStrongRef) : ComAtprotoModerationCreateReportInputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoModerationCreateReportInputSubjectUnion
}

@Serializable
sealed interface ComAtprotoModerationCreateReportOutputSubjectUnion {
    @Serializable
    @SerialName("com.atproto.moderation.createReport#ComAtprotoAdminDefsRepoRef")
    data class ComAtprotoAdminDefsRepoRef(val value: ComAtprotoAdminDefsRepoRef) : ComAtprotoModerationCreateReportOutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.moderation.createReport#ComAtprotoRepoStrongRef")
    data class ComAtprotoRepoStrongRef(val value: ComAtprotoRepoStrongRef) : ComAtprotoModerationCreateReportOutputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoModerationCreateReportOutputSubjectUnion
}

    /**
     * Moderation tool information for tracing the source of the action
     */
    @Serializable
    data class ComAtprotoModerationCreateReportModTool(
/** Name/identifier of the source (e.g., 'bsky-app/android', 'bsky-web/chrome') */        @SerialName("name")
        val name: String,/** Additional arbitrary metadata about the source */        @SerialName("meta")
        val meta: JsonElement?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoModerationCreateReportModTool"
        }
    }

@Serializable
    data class ComAtprotoModerationCreateReportInput(
// Indicates the broad category of violation the report is for.        @SerialName("reasonType")
        val reasonType: ComAtprotoModerationDefsReasonType,// Additional context about the content and violation.        @SerialName("reason")
        val reason: String? = null,        @SerialName("subject")
        val subject: ComAtprotoModerationCreateReportInputSubjectUnion,        @SerialName("modTool")
        val modTool: ComAtprotoModerationCreateReportModTool? = null    )

    @Serializable
    data class ComAtprotoModerationCreateReportOutput(
        @SerialName("id")
        val id: Int,        @SerialName("reasonType")
        val reasonType: ComAtprotoModerationDefsReasonType,        @SerialName("reason")
        val reason: String? = null,        @SerialName("subject")
        val subject: ComAtprotoModerationCreateReportOutputSubjectUnion,        @SerialName("reportedBy")
        val reportedBy: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    )

/**
 * Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.
 *
 * Endpoint: com.atproto.moderation.createReport
 */
suspend fun ATProtoClient.Com.Atproto.Moderation.createReport(
input: ComAtprotoModerationCreateReportInput): ATProtoResponse<ComAtprotoModerationCreateReportOutput> {
    val endpoint = "com.atproto.moderation.createReport"

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
