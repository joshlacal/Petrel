// Lexicon: 1, ID: com.atproto.space.registerNotify
// Register a service to be notified of writes to any repo in a space. Called on the space host. The registering service is named by its service identifier rather than a bare URL, because notifyWrite is delivered with service auth addressed to that identifier; the delivery endpoint is resolved from the service's DID document. Authenticated with a space credential. Re-registering an existing service replaces its registration and extends the expiry.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceRegisterNotifyDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.registerNotify"
}

@Serializable
    data class ComAtprotoSpaceRegisterNotifyInput(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// Service identifier of the subscriber: a DID with an optional service fragment naming the entry in its DID document to deliver to (e.g. 'did:web:syncer.example.com#atproto_space_syncer'). notifyWrite calls are addressed to this identifier.        @SerialName("service")
        val service: String    )

    @Serializable
    data class ComAtprotoSpaceRegisterNotifyOutput(
// When the registration expires. May be later than the expiry of the space credential the request was authenticated with; renew before this time to stay subscribed.        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate    )

sealed class ComAtprotoSpaceRegisterNotifyError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSpaceRegisterNotifyError("SpaceNotFound", "")
        object ServiceNotResolvable: ComAtprotoSpaceRegisterNotifyError("ServiceNotResolvable", "The service identifier could not be resolved to a DID document with a matching service endpoint.")
    }

/**
 * Register a service to be notified of writes to any repo in a space. Called on the space host. The registering service is named by its service identifier rather than a bare URL, because notifyWrite is delivered with service auth addressed to that identifier; the delivery endpoint is resolved from the service's DID document. Authenticated with a space credential. Re-registering an existing service replaces its registration and extends the expiry.
 *
 * Endpoint: com.atproto.space.registerNotify
 */
suspend fun ATProtoClient.Com.Atproto.Space.registerNotify(
input: ComAtprotoSpaceRegisterNotifyInput): ATProtoResponse<ComAtprotoSpaceRegisterNotifyOutput> {
    val endpoint = "com.atproto.space.registerNotify"

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
