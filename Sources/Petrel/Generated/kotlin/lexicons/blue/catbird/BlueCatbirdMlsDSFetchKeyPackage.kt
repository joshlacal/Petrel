// Lexicon: 1, ID: blue.catbird.mlsDS.fetchKeyPackage
// Return and consume a key package for a local user, requested by a remote DS. Fetch and atomically consume one key package for a user in the context of a conversation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSFetchKeyPackageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.fetchKeyPackage"
}

@Serializable
    data class BlueCatbirdMlsDSFetchKeyPackageParameters(
// DID of the user whose key package to fetch        @SerialName("recipientDid")
        val recipientDid: String,// Conversation context for authorization        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class BlueCatbirdMlsDSFetchKeyPackageOutput(
// MLS key package        @SerialName("keyPackage")
        val keyPackage: Bytes,// Hash of the key package        @SerialName("keyPackageHash")
        val keyPackageHash: String    )

sealed class BlueCatbirdMlsDSFetchKeyPackageError(val name: String, val description: String?) {
        object ConversationNotFound: BlueCatbirdMlsDSFetchKeyPackageError("ConversationNotFound", "")
        object RecipientNotFound: BlueCatbirdMlsDSFetchKeyPackageError("RecipientNotFound", "")
        object NoKeyPackagesAvailable: BlueCatbirdMlsDSFetchKeyPackageError("NoKeyPackagesAvailable", "")
    }

/**
 * Return and consume a key package for a local user, requested by a remote DS. Fetch and atomically consume one key package for a user in the context of a conversation.
 *
 * Endpoint: blue.catbird.mlsDS.fetchKeyPackage
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.fetchKeyPackage(
parameters: BlueCatbirdMlsDSFetchKeyPackageParameters): ATProtoResponse<BlueCatbirdMlsDSFetchKeyPackageOutput> {
    val endpoint = "blue.catbird.mlsDS.fetchKeyPackage"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
