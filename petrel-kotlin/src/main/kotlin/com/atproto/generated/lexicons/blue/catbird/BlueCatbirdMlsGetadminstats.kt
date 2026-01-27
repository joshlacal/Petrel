// Lexicon: 1, ID: blue.catbird.mls.getAdminStats
// Get moderation statistics for App Store compliance demonstration Query moderation and admin action statistics. Returns aggregate counts of reports, removals, and block conflicts resolved. Used for App Store review to demonstrate active moderation capabilities. Only accessible to conversation admins.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetAdminStatsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getAdminStats"
}

    /**
     * Aggregate moderation statistics
     */
    @Serializable
    data class BlueCatbirdMlsGetAdminStatsModerationStats(
/** Total number of member reports submitted */        @SerialName("totalReports")
        val totalReports: Int,/** Number of reports awaiting admin review */        @SerialName("pendingReports")
        val pendingReports: Int,/** Number of reports resolved by admins */        @SerialName("resolvedReports")
        val resolvedReports: Int,/** Total number of members removed by admins */        @SerialName("totalRemovals")
        val totalRemovals: Int,/** Number of Bluesky block conflicts resolved by admins */        @SerialName("blockConflictsResolved")
        val blockConflictsResolved: Int,/** Breakdown of reports by category */        @SerialName("reportsByCategory")
        val reportsByCategory: BlueCatbirdMlsGetAdminStatsReportCategoryCounts?,/** Average time to resolve reports (in hours) */        @SerialName("averageResolutionTimeHours")
        val averageResolutionTimeHours: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetAdminStatsModerationStats"
        }
    }

    /**
     * Count of reports by category
     */
    @Serializable
    data class BlueCatbirdMlsGetAdminStatsReportCategoryCounts(
        @SerialName("harassment")
        val harassment: Int?,        @SerialName("spam")
        val spam: Int?,        @SerialName("hateSpeech")
        val hateSpeech: Int?,        @SerialName("violence")
        val violence: Int?,        @SerialName("sexualContent")
        val sexualContent: Int?,        @SerialName("impersonation")
        val impersonation: Int?,        @SerialName("privacyViolation")
        val privacyViolation: Int?,        @SerialName("otherCategory")
        val otherCategory: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetAdminStatsReportCategoryCounts"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetAdminStatsParameters(
// Optional: Get stats for specific conversation (requires admin). Omit for global stats (requires superadmin).        @SerialName("convoId")
        val convoId: String? = null,// Optional: Only include stats since this timestamp        @SerialName("since")
        val since: ATProtocolDate? = null    )

    @Serializable
    data class BlueCatbirdMlsGetAdminStatsOutput(
        @SerialName("stats")
        val stats: BlueCatbirdMlsGetAdminStatsModerationStats,// When these statistics were generated        @SerialName("generatedAt")
        val generatedAt: ATProtocolDate,// Conversation ID if stats are for a specific conversation        @SerialName("convoId")
        val convoId: String? = null    )

sealed class BlueCatbirdMlsGetAdminStatsError(val name: String, val description: String?) {
        object NotAuthorized: BlueCatbirdMlsGetAdminStatsError("NotAuthorized", "User is not authorized to view moderation statistics")
        object ConvoNotFound: BlueCatbirdMlsGetAdminStatsError("ConvoNotFound", "Conversation not found (when convoId is specified)")
    }

/**
 * Get moderation statistics for App Store compliance demonstration Query moderation and admin action statistics. Returns aggregate counts of reports, removals, and block conflicts resolved. Used for App Store review to demonstrate active moderation capabilities. Only accessible to conversation admins.
 *
 * Endpoint: blue.catbird.mls.getAdminStats
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getAdminStats(
parameters: BlueCatbirdMlsGetAdminStatsParameters): ATProtoResponse<BlueCatbirdMlsGetAdminStatsOutput> {
    val endpoint = "blue.catbird.mls.getAdminStats"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
