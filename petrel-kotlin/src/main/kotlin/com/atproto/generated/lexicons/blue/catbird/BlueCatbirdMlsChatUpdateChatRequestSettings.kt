// Lexicon: 1, ID: blue.catbird.mlsChat.updateChatRequestSettings
// Update user's chat request settings
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUpdateChatRequestSettingsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.updateChatRequestSettings"
}

@Serializable
    data class BlueCatbirdMlsChatUpdateChatRequestSettingsInput(
// Allow users you follow to bypass request system        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean? = null,// Allow users who follow you to bypass request system        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean? = null,// Days until pending requests auto-expire        @SerialName("autoExpireDays")
        val autoExpireDays: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatUpdateChatRequestSettingsOutput(
        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean,        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean,        @SerialName("autoExpireDays")
        val autoExpireDays: Int    )

/**
 * Update user's chat request settings
 *
 * Endpoint: blue.catbird.mlsChat.updateChatRequestSettings
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.updateChatRequestSettings(
input: BlueCatbirdMlsChatUpdateChatRequestSettingsInput): ATProtoResponse<BlueCatbirdMlsChatUpdateChatRequestSettingsOutput> {
    val endpoint = "blue.catbird.mlsChat.updateChatRequestSettings"

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
