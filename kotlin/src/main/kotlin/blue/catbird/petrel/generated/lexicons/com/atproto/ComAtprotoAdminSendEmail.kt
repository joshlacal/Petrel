// Lexicon: 1, ID: com.atproto.admin.sendEmail
// Send email to a user's account email address.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminSendEmailDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.sendEmail"
}

@Serializable
    data class ComAtprotoAdminSendEmailInput(
        @SerialName("recipientDid")
        val recipientDid: DID,        @SerialName("content")
        val content: String,        @SerialName("subject")
        val subject: String? = null,        @SerialName("senderDid")
        val senderDid: DID,// Additional comment by the sender that won't be used in the email itself but helpful to provide more context for moderators/reviewers        @SerialName("comment")
        val comment: String? = null    )

    @Serializable
    data class ComAtprotoAdminSendEmailOutput(
        @SerialName("sent")
        val sent: Boolean    )

/**
 * Send email to a user's account email address.
 *
 * Endpoint: com.atproto.admin.sendEmail
 */
suspend fun ATProtoClient.Com.Atproto.Admin.sendEmail(
input: ComAtprotoAdminSendEmailInput): ATProtoResponse<ComAtprotoAdminSendEmailOutput> {
    val endpoint = "com.atproto.admin.sendEmail"

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
