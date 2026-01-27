// Lexicon: 1, ID: com.atproto.admin.getSubjectStatus
// Get the service-specific admin status of a subject (account, record, or blob).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminGetSubjectStatusDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.getSubjectStatus"
}

@Serializable
sealed interface ComAtprotoAdminGetSubjectStatusOutputSubjectUnion {
    @Serializable
    @SerialName("com.atproto.admin.getSubjectStatus#ComAtprotoAdminDefsRepoRef")
    data class ComAtprotoAdminDefsRepoRef(val value: ComAtprotoAdminDefsRepoRef) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.getSubjectStatus#ComAtprotoRepoStrongRef")
    data class ComAtprotoRepoStrongRef(val value: ComAtprotoRepoStrongRef) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion

    @Serializable
    @SerialName("com.atproto.admin.getSubjectStatus#ComAtprotoAdminDefsRepoBlobRef")
    data class ComAtprotoAdminDefsRepoBlobRef(val value: ComAtprotoAdminDefsRepoBlobRef) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoAdminGetSubjectStatusOutputSubjectUnion
}

@Serializable
    data class ComAtprotoAdminGetSubjectStatusParameters(
        @SerialName("did")
        val did: DID? = null,        @SerialName("uri")
        val uri: ATProtocolURI? = null,        @SerialName("blob")
        val blob: CID? = null    )

    @Serializable
    data class ComAtprotoAdminGetSubjectStatusOutput(
        @SerialName("subject")
        val subject: ComAtprotoAdminGetSubjectStatusOutputSubjectUnion,        @SerialName("takedown")
        val takedown: ComAtprotoAdminDefsStatusAttr? = null,        @SerialName("deactivated")
        val deactivated: ComAtprotoAdminDefsStatusAttr? = null    )

/**
 * Get the service-specific admin status of a subject (account, record, or blob).
 *
 * Endpoint: com.atproto.admin.getSubjectStatus
 */
suspend fun ATProtoClient.Com.Atproto.Admin.getSubjectStatus(
parameters: ComAtprotoAdminGetSubjectStatusParameters): ATProtoResponse<ComAtprotoAdminGetSubjectStatusOutput> {
    val endpoint = "com.atproto.admin.getSubjectStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
