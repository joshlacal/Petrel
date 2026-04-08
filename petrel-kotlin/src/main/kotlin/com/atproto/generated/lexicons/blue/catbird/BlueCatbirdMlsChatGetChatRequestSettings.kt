// Lexicon: 1, ID: blue.catbird.mlsChat.getChatRequestSettings
// Get user's chat request settings
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetChatRequestSettingsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getChatRequestSettings"
}

    @Serializable
    data class BlueCatbirdMlsChatGetChatRequestSettingsOutput(
// Allow users you follow to bypass request system        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean,// Allow users who follow you to bypass request system        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean,// Days until pending requests auto-expire        @SerialName("autoExpireDays")
        val autoExpireDays: Int    )

/**
 * Get user's chat request settings
 *
 * Endpoint: blue.catbird.mlsChat.getChatRequestSettings
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getChatRequestSettings(
): ATProtoResponse<BlueCatbirdMlsChatGetChatRequestSettingsOutput> {
    val endpoint = "blue.catbird.mlsChat.getChatRequestSettings"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
