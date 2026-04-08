// Lexicon: 1, ID: blue.catbird.mlsChat.device
// Per-device MLS signature key published to the user's repo. Used to verify that key packages served by the delivery service belong to an authorized device.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatDeviceDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.device"
}

    /**
     * Per-device MLS signature key published to the user's repo. Used to verify that key packages served by the delivery service belong to an authorized device.
     */
    @Serializable
    data class BlueCatbirdMlsChatDevice(
/** Unique device identifier (server-assigned or client-generated UUID) */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name (e.g. 'Josh's iPhone') */        @SerialName("deviceName")
        val deviceName: String? = null,/** The MLS credential signature public key for this device */        @SerialName("mlsSignaturePublicKey")
        val mlsSignaturePublicKey: ByteArray,/** Signature algorithm: 'ed25519' or 'p256' */        @SerialName("algorithm")
        val algorithm: String,/** Device platform: 'ios', 'macos', 'catmos', 'android' */        @SerialName("platform")
        val platform: String? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
