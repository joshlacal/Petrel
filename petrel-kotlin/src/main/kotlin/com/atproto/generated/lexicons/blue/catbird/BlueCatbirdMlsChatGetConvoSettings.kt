// Lexicon: 1, ID: blue.catbird.mlsChat.getConvoSettings
// Get conversation settings and policy Retrieve current settings and policy for a conversation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetConvoSettingsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getConvoSettings"
}

@Serializable
    data class BlueCatbirdMlsChatGetConvoSettingsParameters(
// Conversation identifier        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsChatGetConvoSettingsOutput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Conversation policy object (structure varies by conversation type)        @SerialName("policy")
        val policy: JsonElement    )

sealed class BlueCatbirdMlsChatGetConvoSettingsError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatGetConvoSettingsError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatGetConvoSettingsError("NotMember", "Caller is not a member of this conversation")
    }

/**
 * Get conversation settings and policy Retrieve current settings and policy for a conversation.
 *
 * Endpoint: blue.catbird.mlsChat.getConvoSettings
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getConvoSettings(
parameters: BlueCatbirdMlsChatGetConvoSettingsParameters): ATProtoResponse<BlueCatbirdMlsChatGetConvoSettingsOutput> {
    val endpoint = "blue.catbird.mlsChat.getConvoSettings"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
