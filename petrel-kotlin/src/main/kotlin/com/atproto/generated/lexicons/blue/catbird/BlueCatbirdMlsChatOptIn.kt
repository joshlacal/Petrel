// Lexicon: 1, ID: blue.catbird.mlsChat.optIn
// Manage MLS chat opt-in status (consolidates optIn + optOut + getOptInStatus + getChatRequestSettings + updateChatRequestSettings + acceptChatRequest + declineChatRequest + sendChatRequest) Manage MLS chat participation. Supports opting in/out, checking status for multiple DIDs, and managing chat request settings.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatOptInDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.optIn"
}

    @Serializable
    data class BlueCatbirdMlsChatOptInOptInStatus(
/** User DID */        @SerialName("did")
        val did: DID,/** Whether the user has opted into MLS chat */        @SerialName("optedIn")
        val optedIn: Boolean,/** When the user opted in (if applicable) */        @SerialName("optedInAt")
        val optedInAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatOptInOptInStatus"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatOptInInput(
// Action to perform: 'optIn' enables MLS chat, 'optOut' disables it, 'getStatus' checks opt-in status for one or more DIDs, 'getSettings' retrieves chat request settings, 'updateSettings' updates chat request settings        @SerialName("action")
        val action: String,// DIDs to check status for (used with 'getStatus' action)        @SerialName("dids")
        val dids: List<DID>? = null,// Device identifier (optional, for 'optIn' action)        @SerialName("deviceId")
        val deviceId: String? = null,// Allow followers to bypass chat request approval (for 'updateSettings' action)        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean? = null,// Allow accounts you follow to bypass chat request approval (for 'updateSettings' action)        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean? = null,// Auto-expire pending chat requests after N days, 0 = no expiry (for 'updateSettings' action)        @SerialName("autoExpireDays")
        val autoExpireDays: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatOptInOutput(
// Whether the opt-in/opt-out operation succeeded        @SerialName("success")
        val success: Boolean? = null,// Current opt-in status of the caller (for 'optIn'/'optOut')        @SerialName("optedIn")
        val optedIn: Boolean? = null,// When the user opted in (for 'optIn')        @SerialName("optedInAt")
        val optedInAt: ATProtocolDate? = null,// Opt-in statuses for requested DIDs (for 'getStatus')        @SerialName("statuses")
        val statuses: List<BlueCatbirdMlsChatOptInOptInStatus>? = null,// Whether followers can bypass chat request approval (for 'getSettings'/'updateSettings')        @SerialName("allowFollowersBypass")
        val allowFollowersBypass: Boolean? = null,// Whether accounts you follow can bypass chat request approval (for 'getSettings'/'updateSettings')        @SerialName("allowFollowingBypass")
        val allowFollowingBypass: Boolean? = null,// Auto-expire pending chat requests after N days (for 'getSettings'/'updateSettings')        @SerialName("autoExpireDays")
        val autoExpireDays: Int? = null    )

sealed class BlueCatbirdMlsChatOptInError(val name: String, val description: String?) {
        object InvalidAction: BlueCatbirdMlsChatOptInError("InvalidAction", "Unknown action value")
        object AlreadyOptedIn: BlueCatbirdMlsChatOptInError("AlreadyOptedIn", "User is already opted in")
        object AlreadyOptedOut: BlueCatbirdMlsChatOptInError("AlreadyOptedOut", "User is already opted out")
        object TooManyDids: BlueCatbirdMlsChatOptInError("TooManyDids", "Too many DIDs requested (max 100)")
    }

/**
 * Manage MLS chat opt-in status (consolidates optIn + optOut + getOptInStatus + getChatRequestSettings + updateChatRequestSettings + acceptChatRequest + declineChatRequest + sendChatRequest) Manage MLS chat participation. Supports opting in/out, checking status for multiple DIDs, and managing chat request settings.
 *
 * Endpoint: blue.catbird.mlsChat.optIn
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.optIn(
input: BlueCatbirdMlsChatOptInInput): ATProtoResponse<BlueCatbirdMlsChatOptInOutput> {
    val endpoint = "blue.catbird.mlsChat.optIn"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
