// Lexicon: 1, ID: blue.catbird.mlsChat.resolveReport
// Resolve a report with an action (admin-only) Mark a report as resolved with the action taken. Admin-only operation. Records resolution in audit trail.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatResolveReportDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.resolveReport"
}

@Serializable
    data class BlueCatbirdMlsChatResolveReportInput(
// Report identifier to resolve        @SerialName("reportId")
        val reportId: String,// Action taken in response to report        @SerialName("action")
        val action: String,// Optional internal notes about resolution        @SerialName("notes")
        val notes: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatResolveReportOutput(
// Whether resolution succeeded        @SerialName("ok")
        val ok: Boolean    )

sealed class BlueCatbirdMlsChatResolveReportError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsChatResolveReportError("NotAdmin", "Caller is not an admin")
        object ReportNotFound: BlueCatbirdMlsChatResolveReportError("ReportNotFound", "Report does not exist")
        object AlreadyResolved: BlueCatbirdMlsChatResolveReportError("AlreadyResolved", "Report was already resolved")
    }

/**
 * Resolve a report with an action (admin-only) Mark a report as resolved with the action taken. Admin-only operation. Records resolution in audit trail.
 *
 * Endpoint: blue.catbird.mlsChat.resolveReport
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.resolveReport(
input: BlueCatbirdMlsChatResolveReportInput): ATProtoResponse<BlueCatbirdMlsChatResolveReportOutput> {
    val endpoint = "blue.catbird.mlsChat.resolveReport"

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
