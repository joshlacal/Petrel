// Lexicon: 1, ID: blue.catbird.mls.getKeyPackageStats
// Get key package inventory statistics for the authenticated user to determine when replenishment is needed
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetKeyPackageStatsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getKeyPackageStats"
}

    /**
     * Key package statistics for a specific cipher suite
     */
    @Serializable
    data class BlueCatbirdMlsGetKeyPackageStatsCipherSuiteStats(
/** Cipher suite name */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Available key packages for this suite */        @SerialName("available")
        val available: Int,/** Total consumed key packages for this suite */        @SerialName("consumed")
        val consumed: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetKeyPackageStatsCipherSuiteStats"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetKeyPackageStatsParameters(
// DID to fetch stats for (defaults to authenticated user)        @SerialName("did")
        val did: DID? = null,// Filter by specific cipher suite        @SerialName("cipherSuite")
        val cipherSuite: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetKeyPackageStatsOutput(
// Number of unconsumed key packages available        @SerialName("available")
        val available: Int,// Recommended minimum inventory threshold        @SerialName("threshold")
        val threshold: Int,// True if available < threshold OR predicted to deplete in < 3 days        @SerialName("needsReplenish")
        val needsReplenish: Boolean,// Total number of key packages (all states: available + consumed)        @SerialName("total")
        val total: Int,// Total number of consumed key packages        @SerialName("consumed")
        val consumed: Int,// Number of key packages consumed in the last 24 hours        @SerialName("consumedLast24h")
        val consumedLast24h: Int,// Number of key packages consumed in the last 7 days        @SerialName("consumedLast7d")
        val consumedLast7d: Int,// Average key packages consumed per day, multiplied by 100 (e.g., 250 = 2.5 packages/day). Calculated from 7-day window.        @SerialName("averageDailyConsumption")
        val averageDailyConsumption: Int,// Predicted days until key package pool depletes, multiplied by 100 (e.g., 350 = 3.5 days). Null if insufficient data or rate is too low.        @SerialName("predictedDepletionDays")
        val predictedDepletionDays: Int? = null,// Human-readable time until oldest key package expires (e.g., '23d 4h')        @SerialName("oldestExpiresIn")
        val oldestExpiresIn: String? = null,// Breakdown by cipher suite        @SerialName("byCipherSuite")
        val byCipherSuite: List<BlueCatbirdMlsGetKeyPackageStatsCipherSuiteStats>? = null    )

sealed class BlueCatbirdMlsGetKeyPackageStatsError(val name: String, val description: String?) {
        object InvalidDid: BlueCatbirdMlsGetKeyPackageStatsError("InvalidDid", "The provided DID is invalid")
    }

/**
 * Get key package inventory statistics for the authenticated user to determine when replenishment is needed
 *
 * Endpoint: blue.catbird.mls.getKeyPackageStats
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getKeyPackageStats(
parameters: BlueCatbirdMlsGetKeyPackageStatsParameters): ATProtoResponse<BlueCatbirdMlsGetKeyPackageStatsOutput> {
    val endpoint = "blue.catbird.mls.getKeyPackageStats"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
