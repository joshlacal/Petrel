// Lexicon: 1, ID: blue.catbird.mlsChat.registerDevice
// Register a device for multi-device MLS support. Each device gets a unique device ID and credential (did:plc:user#device-uuid). Required for proper multi-device group conversations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRegisterDeviceDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.registerDevice"
}

    @Serializable
    data class BlueCatbirdMlsChatRegisterDeviceKeyPackageItem(
/** Base64-encoded MLS key package */        @SerialName("keyPackage")
        val keyPackage: String,/** MLS cipher suite (e.g., 'MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519') */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Key package expiration time */        @SerialName("expires")
        val expires: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatRegisterDeviceKeyPackageItem"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatRegisterDeviceWelcomeMessage(
/** Conversation ID */        @SerialName("convoId")
        val convoId: String,/** Base64-encoded MLS Welcome message */        @SerialName("welcome")
        val welcome: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatRegisterDeviceWelcomeMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatRegisterDeviceInput(
// Human-readable device name (e.g., 'Josh's iPhone', 'MacBook Pro')        @SerialName("deviceName")
        val deviceName: String,// Persistent device UUID (stored in iCloud Keychain). Allows server to detect device re-registration and cleanup old key packages. Optional for backward compatibility.        @SerialName("deviceUUID")
        val deviceUUID: String? = null,// MLS key packages for this device (1-200 packages)        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsChatRegisterDeviceKeyPackageItem>,// Device Ed25519 signature public key (32 bytes)        @SerialName("signaturePublicKey")
        val signaturePublicKey: ByteArray    )

    @Serializable
    data class BlueCatbirdMlsChatRegisterDeviceOutput(
// Server-generated device ID (UUID)        @SerialName("deviceId")
        val deviceId: String,// Full device credential DID (did:plc:user#device-uuid). Use this as the MLS credential identity.        @SerialName("mlsDid")
        val mlsDid: String,// Conversation IDs that this device can auto-join        @SerialName("autoJoinedConvos")
        val autoJoinedConvos: List<String>,// Welcome messages for auto-joining conversations (may be null)        @SerialName("welcomeMessages")
        val welcomeMessages: List<BlueCatbirdMlsChatRegisterDeviceWelcomeMessage>? = null    )

sealed class BlueCatbirdMlsChatRegisterDeviceError(val name: String, val description: String?) {
        object InvalidDeviceName: BlueCatbirdMlsChatRegisterDeviceError("InvalidDeviceName", "")
        object InvalidKeyPackages: BlueCatbirdMlsChatRegisterDeviceError("InvalidKeyPackages", "")
        object InvalidSignatureKey: BlueCatbirdMlsChatRegisterDeviceError("InvalidSignatureKey", "")
        object DeviceAlreadyRegistered: BlueCatbirdMlsChatRegisterDeviceError("DeviceAlreadyRegistered", "")
        object TooManyDevices: BlueCatbirdMlsChatRegisterDeviceError("TooManyDevices", "")
    }

/**
 * Register a device for multi-device MLS support. Each device gets a unique device ID and credential (did:plc:user#device-uuid). Required for proper multi-device group conversations.
 *
 * Endpoint: blue.catbird.mlsChat.registerDevice
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.registerDevice(
input: BlueCatbirdMlsChatRegisterDeviceInput): ATProtoResponse<BlueCatbirdMlsChatRegisterDeviceOutput> {
    val endpoint = "blue.catbird.mlsChat.registerDevice"

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
