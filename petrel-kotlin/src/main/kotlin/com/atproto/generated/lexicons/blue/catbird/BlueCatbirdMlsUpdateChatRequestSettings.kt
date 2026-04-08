// Lexicon: 1, ID: blue.catbird.mls.updateChatRequestSettings
// Update user's chat request settings
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsUpdateChatRequestSettingsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.updateChatRequestSettings"
}

@Serializable
    data class BlueCatbirdMlsUpdateChatRequestSettingsInput(
// Allow users you follow to bypass request system        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean? = null,// Allow users who follow you to bypass request system        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean? = null,// Days until pending requests auto-expire        @SerialName("autoExpireDays")
        val autoExpireDays: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsUpdateChatRequestSettingsOutput(
        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean,        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean,        @SerialName("autoExpireDays")
        val autoExpireDays: Int    )

/**
 * Update user's chat request settings
 *
 * Endpoint: blue.catbird.mls.updateChatRequestSettings
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.updateChatRequestSettings(
input: BlueCatbirdMlsUpdateChatRequestSettingsInput): ATProtoResponse<BlueCatbirdMlsUpdateChatRequestSettingsOutput> {
    val endpoint = "blue.catbird.mls.updateChatRequestSettings"

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
