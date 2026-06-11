// Lexicon: 1, ID: app.bsky.graph.verification
// Record declaring a verification relationship between two accounts. Verifications are only considered valid by an app if issued by an account the app considers trusted.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphVerificationDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.verification"
}

    /**
     * Record declaring a verification relationship between two accounts. Verifications are only considered valid by an app if issued by an account the app considers trusted.
     */
    @Serializable
    data class AppBskyGraphVerification(
/** DID of the subject the verification applies to. */        @SerialName("subject")
        val subject: DID,/** Handle of the subject the verification applies to at the moment of verifying, which might not be the same at the time of viewing. The verification is only valid if the current handle matches the one at the time of verifying. */        @SerialName("handle")
        val handle: Handle,/** Display name of the subject the verification applies to at the moment of verifying, which might not be the same at the time of viewing. The verification is only valid if the current displayName matches the one at the time of verifying. */        @SerialName("displayName")
        val displayName: String,/** Date of when the verification was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
