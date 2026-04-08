// Lexicon: 1, ID: place.stream.graph.getFollowingUser
// Get whether or not user A is following user B.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamGraphGetFollowingUserDefs {
    const val TYPE_IDENTIFIER = "place.stream.graph.getFollowingUser"
}

@Serializable
    data class PlaceStreamGraphGetFollowingUserParameters(
// The DID of the potentially-following user        @SerialName("userDID")
        val userDID: DID,// The DID of the user potentially being followed        @SerialName("subjectDID")
        val subjectDID: DID    )

    @Serializable
    data class PlaceStreamGraphGetFollowingUserOutput(
        @SerialName("follow")
        val follow: ComAtprotoRepoStrongRef? = null    )

/**
 * Get whether or not user A is following user B.
 *
 * Endpoint: place.stream.graph.getFollowingUser
 */
suspend fun ATProtoClient.Place.Stream.Graph.getFollowingUser(
parameters: PlaceStreamGraphGetFollowingUserParameters): ATProtoResponse<PlaceStreamGraphGetFollowingUserOutput> {
    val endpoint = "place.stream.graph.getFollowingUser"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
