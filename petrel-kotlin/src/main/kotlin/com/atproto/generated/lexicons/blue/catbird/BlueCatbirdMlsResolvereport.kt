// Lexicon: 1, ID: blue.catbird.mls.resolveReport
// Resolve a report with an action (admin-only) Mark a report as resolved with the action taken. Admin-only operation. Records resolution in audit trail.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsResolveReportDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.resolveReport"
}

@Serializable
    data class BlueCatbirdMlsResolveReportInput(
// Report identifier to resolve        @SerialName("reportId")
        val reportId: String,// Action taken in response to report        @SerialName("action")
        val action: String,// Optional internal notes about resolution        @SerialName("notes")
        val notes: String? = null    )

    @Serializable
    data class BlueCatbirdMlsResolveReportOutput(
// Whether resolution succeeded        @SerialName("ok")
        val ok: Boolean    )

sealed class BlueCatbirdMlsResolveReportError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsResolveReportError("NotAdmin", "Caller is not an admin")
        object ReportNotFound: BlueCatbirdMlsResolveReportError("ReportNotFound", "Report does not exist")
        object AlreadyResolved: BlueCatbirdMlsResolveReportError("AlreadyResolved", "Report was already resolved")
    }

/**
 * Resolve a report with an action (admin-only) Mark a report as resolved with the action taken. Admin-only operation. Records resolution in audit trail.
 *
 * Endpoint: blue.catbird.mls.resolveReport
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.resolveReport(
input: BlueCatbirdMlsResolveReportInput): ATProtoResponse<BlueCatbirdMlsResolveReportOutput> {
    val endpoint = "blue.catbird.mls.resolveReport"

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
