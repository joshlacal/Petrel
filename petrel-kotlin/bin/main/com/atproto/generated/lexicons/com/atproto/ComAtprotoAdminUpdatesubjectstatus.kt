// Lexicon: 1, ID: com.atproto.admin.updateSubjectStatus
// Update the service-specific admin status of a subject (account, record, or blob).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminUpdateSubjectStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.updateSubjectStatus"
}

@Serializable
sealed interface ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion {
    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoAdminDefsRepoRef")
    data class ComAtprotoAdminDefsRepoRef(val value: ComAtprotoAdminDefsRepoRef) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoRepoStrongRef")
    data class ComAtprotoRepoStrongRef(val value: ComAtprotoRepoStrongRef) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoAdminDefsRepoBlobRef")
    data class ComAtprotoAdminDefsRepoBlobRef(val value: ComAtprotoAdminDefsRepoBlobRef) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion
}

@Serializable
sealed interface ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion {
    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoAdminDefsRepoRef")
    data class ComAtprotoAdminDefsRepoRef(val value: ComAtprotoAdminDefsRepoRef) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoRepoStrongRef")
    data class ComAtprotoRepoStrongRef(val value: ComAtprotoRepoStrongRef) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.updateSubjectStatus#ComAtprotoAdminDefsRepoBlobRef")
    data class ComAtprotoAdminDefsRepoBlobRef(val value: ComAtprotoAdminDefsRepoBlobRef) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion
}

@Serializable
    data class ComAtprotoAdminUpdateSubjectStatusInput(
        @SerialName("subject")
        val subject: ComAtprotoAdminUpdateSubjectStatusInputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefsStatusAttr? = null,        @SerialName("deactivated")
        val deactivated: ComAtprotoAdminDefsStatusAttr? = null    )

    @Serializable
    data class ComAtprotoAdminUpdateSubjectStatusOutput(
        @SerialName("subject")
        val subject: ComAtprotoAdminUpdateSubjectStatusOutputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefsStatusAttr? = null    )

/**
 * Update the service-specific admin status of a subject (account, record, or blob).
 *
 * Endpoint: com.atproto.admin.updateSubjectStatus
 */
suspend fun ATProtoClient.Com.Atproto.Admin.updateSubjectStatus(
input: ComAtprotoAdminUpdateSubjectStatusInput): ATProtoResponse<ComAtprotoAdminUpdateSubjectStatusOutput> {
    val endpoint = "com.atproto.admin.updateSubjectStatus"

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
