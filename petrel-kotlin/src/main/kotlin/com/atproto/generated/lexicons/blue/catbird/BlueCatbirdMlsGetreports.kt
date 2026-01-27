// Lexicon: 1, ID: blue.catbird.mls.getReports
// Get reports for a conversation (admin-only) Retrieve reports for a conversation. Admin-only endpoint. Returns encrypted report blobs that admins must decrypt locally using MLS group key.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetReportsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getReports"
}

    /**
     * Report metadata and encrypted content blob
     */
    @Serializable
    data class BlueCatbirdMlsGetReportsReportView(
/** Report identifier */        @SerialName("id")
        val id: String,/** DID of member who submitted report */        @SerialName("reporterDid")
        val reporterDid: DID,/** DID of reported member */        @SerialName("reportedDid")
        val reportedDid: DID,/** Encrypted report content (admin must decrypt locally) */        @SerialName("encryptedContent")
        val encryptedContent: ByteArray,/** When report was submitted */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Report status */        @SerialName("status")
        val status: String,/** DID of admin who resolved report */        @SerialName("resolvedBy")
        val resolvedBy: DID?,/** When report was resolved */        @SerialName("resolvedAt")
        val resolvedAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetReportsReportView"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetReportsParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Filter by report status        @SerialName("status")
        val status: String? = null,// Maximum number of reports to return        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsGetReportsOutput(
// List of reports (encrypted content)        @SerialName("reports")
        val reports: List<BlueCatbirdMlsGetReportsReportView>    )

sealed class BlueCatbirdMlsGetReportsError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsGetReportsError("NotAdmin", "Caller is not an admin")
        object ConvoNotFound: BlueCatbirdMlsGetReportsError("ConvoNotFound", "Conversation not found")
    }

/**
 * Get reports for a conversation (admin-only) Retrieve reports for a conversation. Admin-only endpoint. Returns encrypted report blobs that admins must decrypt locally using MLS group key.
 *
 * Endpoint: blue.catbird.mls.getReports
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getReports(
parameters: BlueCatbirdMlsGetReportsParameters): ATProtoResponse<BlueCatbirdMlsGetReportsOutput> {
    val endpoint = "blue.catbird.mls.getReports"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
