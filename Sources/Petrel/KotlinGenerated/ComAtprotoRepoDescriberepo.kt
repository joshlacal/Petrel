// Lexicon: 1, ID: com.atproto.repo.describeRepo
// Get information about an account and repository, including the list of collections. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoRepoDescriberepo {
    const val TYPE_IDENTIFIER = "com.atproto.repo.describeRepo"

    @Serializable
    data class Parameters(
// The handle or DID of the repo.        @SerialName("repo")
        val repo: ATIdentifier    )

        @Serializable
    data class Output(
        @SerialName("handle")
        val handle: Handle,        @SerialName("did")
        val did: DID,// The complete DID document for this account.        @SerialName("didDoc")
        val didDoc: JsonElement,// List of all the collections (NSIDs) for which this repo contains at least one record.        @SerialName("collections")
        val collections: List<NSID>,// Indicates if handle is currently valid (resolves bi-directionally)        @SerialName("handleIsCorrect")
        val handleIsCorrect: Boolean    )

}

/**
 * Get information about an account and repository, including the list of collections. Does not require auth.
 *
 * Endpoint: com.atproto.repo.describeRepo
 */
suspend fun ATProtoClient.Com.Atproto.Repo.describerepo(
parameters: ComAtprotoRepoDescriberepo.Parameters): ATProtoResponse<ComAtprotoRepoDescriberepo.Output> {
    val endpoint = "com.atproto.repo.describeRepo"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
