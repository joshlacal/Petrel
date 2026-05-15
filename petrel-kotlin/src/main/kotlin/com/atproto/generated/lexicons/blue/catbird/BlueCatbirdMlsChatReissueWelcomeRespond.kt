// Lexicon: 1, ID: blue.catbird.mlsChat.reissueWelcomeRespond
// Inviter/admin response to a pending reissueWelcome request. Stores a fresh MLS Welcome for the recipient device and marks the reissue request as answered.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatReissueWelcomeRespondDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.reissueWelcomeRespond"
}

@Serializable
    data class BlueCatbirdMlsChatReissueWelcomeRespondInput(
// Identifier returned by the server-side reissue request record.        @SerialName("requestId")
        val requestId: String,// TLS-serialized MLS Welcome generated for the recipient device.        @SerialName("welcomeBlob")
        val welcomeBlob: Bytes,// Optional hex-encoded SHA-256 hash of the recipient key package used to generate this Welcome.        @SerialName("keyPackageHash")
        val keyPackageHash: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatReissueWelcomeRespondOutput(
// True when the Welcome was stored and the request was marked answered.        @SerialName("stored")
        val stored: Boolean,// Echo of the answered reissue request identifier.        @SerialName("requestId")
        val requestId: String,// Server identifier for the stored Welcome blob.        @SerialName("welcomeBlobId")
        val welcomeBlobId: String,// Server timestamp when the Welcome was stored.        @SerialName("respondedAt")
        val respondedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatReissueWelcomeRespondError(val name: String, val description: String?) {
        object RequestNotFound: BlueCatbirdMlsChatReissueWelcomeRespondError("RequestNotFound", "No pending unanswered reissue request exists for requestId.")
        object Unauthorized: BlueCatbirdMlsChatReissueWelcomeRespondError("Unauthorized", "Caller is not an active admin/inviter for the request conversation.")
        object InvalidWelcome: BlueCatbirdMlsChatReissueWelcomeRespondError("InvalidWelcome", "Welcome bytes are missing or invalid.")
    }

/**
 * Inviter/admin response to a pending reissueWelcome request. Stores a fresh MLS Welcome for the recipient device and marks the reissue request as answered.
 *
 * Endpoint: blue.catbird.mlsChat.reissueWelcomeRespond
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.reissueWelcomeRespond(
input: BlueCatbirdMlsChatReissueWelcomeRespondInput): ATProtoResponse<BlueCatbirdMlsChatReissueWelcomeRespondOutput> {
    val endpoint = "blue.catbird.mlsChat.reissueWelcomeRespond"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
