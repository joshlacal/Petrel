// Lexicon: 1, ID: place.stream.metadata.configuration
// Default metadata record for livestream including content warnings, rights, and distribution policy
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMetadataConfigurationDefs {
    const val TYPE_IDENTIFIER = "place.stream.metadata.configuration"
}

    /**
     * Default metadata record for livestream including content warnings, rights, and distribution policy
     */
    @Serializable
    data class PlaceStreamMetadataConfiguration(
        @SerialName("contentWarnings")
        val contentWarnings: PlaceStreamMetadataContentWarnings? = null,        @SerialName("contentRights")
        val contentRights: PlaceStreamMetadataContentRights? = null,        @SerialName("distributionPolicy")
        val distributionPolicy: PlaceStreamMetadataDistributionPolicy? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
