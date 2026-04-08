// Lexicon: 1, ID: app.bsky.contact.importContacts
// Import contacts for securely matching with other users. This follows the protocol explained in https://docs.bsky.app/blog/contact-import-rfc. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactImportContactsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.importContacts"
}

@Serializable
    data class AppBskyContactImportContactsInput(
// JWT to authenticate the call. Use the JWT received as a response to the call to `app.bsky.contact.verifyPhone`.        @SerialName("token")
        val token: String,// List of phone numbers in global E.164 format (e.g., '+12125550123'). Phone numbers that cannot be normalized into a valid phone number will be discarded. Should not repeat the 'phone' input used in `app.bsky.contact.verifyPhone`.        @SerialName("contacts")
        val contacts: List<String>    )

    @Serializable
    data class AppBskyContactImportContactsOutput(
// The users that matched during import and their indexes on the input contacts, so the client can correlate with its local list.        @SerialName("matchesAndContactIndexes")
        val matchesAndContactIndexes: List<AppBskyContactDefsMatchAndContactIndex>    )

sealed class AppBskyContactImportContactsError(val name: String, val description: String?) {
        object InvalidDid: AppBskyContactImportContactsError("InvalidDid", "")
        object InvalidContacts: AppBskyContactImportContactsError("InvalidContacts", "")
        object TooManyContacts: AppBskyContactImportContactsError("TooManyContacts", "")
        object InvalidToken: AppBskyContactImportContactsError("InvalidToken", "")
        object InternalError: AppBskyContactImportContactsError("InternalError", "")
    }

/**
 * Import contacts for securely matching with other users. This follows the protocol explained in https://docs.bsky.app/blog/contact-import-rfc. Requires authentication.
 *
 * Endpoint: app.bsky.contact.importContacts
 */
suspend fun ATProtoClient.App.Bsky.Contact.importContacts(
input: AppBskyContactImportContactsInput): ATProtoResponse<AppBskyContactImportContactsOutput> {
    val endpoint = "app.bsky.contact.importContacts"

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
