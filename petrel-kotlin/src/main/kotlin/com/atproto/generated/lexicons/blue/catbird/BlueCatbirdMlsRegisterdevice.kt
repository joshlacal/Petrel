// Lexicon: 1, ID: blue.catbird.mls.registerDevice
// Register a device for multi-device MLS support. Each device gets a unique device ID and credential (did:plc:user#device-uuid). Required for proper multi-device group conversations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsRegisterDeviceDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.registerDevice"
}

    @Serializable
    data class BlueCatbirdMlsRegisterDeviceKeyPackageItem(
/** Base64-encoded MLS key package */        @SerialName("keyPackage")
        val keyPackage: String,/** MLS cipher suite (e.g., 'MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519') */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Key package expiration time */        @SerialName("expires")
        val expires: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsRegisterDeviceKeyPackageItem"
        }
    }

    @Serializable
    data class BlueCatbirdMlsRegisterDeviceWelcomeMessage(
/** Conversation ID */        @SerialName("convoId")
        val convoId: String,/** Base64-encoded MLS Welcome message */        @SerialName("welcome")
        val welcome: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsRegisterDeviceWelcomeMessage"
        }
    }

@Serializable
    data class BlueCatbirdMlsRegisterDeviceInput(
// Human-readable device name (e.g., 'Josh's iPhone', 'MacBook Pro')        @SerialName("deviceName")
        val deviceName: String,// Persistent device UUID (stored in iCloud Keychain). Allows server to detect device re-registration and cleanup old key packages. Optional for backward compatibility.        @SerialName("deviceUUID")
        val deviceUUID: String? = null,// MLS key packages for this device (1-200 packages)        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsRegisterDeviceKeyPackageItem>,// Device Ed25519 signature public key (32 bytes)        @SerialName("signaturePublicKey")
        val signaturePublicKey: ByteArray    )

    @Serializable
    data class BlueCatbirdMlsRegisterDeviceOutput(
// Server-generated device ID (UUID)        @SerialName("deviceId")
        val deviceId: String,// Full device credential DID (did:plc:user#device-uuid). Use this as the MLS credential identity.        @SerialName("mlsDid")
        val mlsDid: String,// Conversation IDs that this device can auto-join        @SerialName("autoJoinedConvos")
        val autoJoinedConvos: List<String>,// Welcome messages for auto-joining conversations (may be null)        @SerialName("welcomeMessages")
        val welcomeMessages: List<BlueCatbirdMlsRegisterDeviceWelcomeMessage>? = null    )

sealed class BlueCatbirdMlsRegisterDeviceError(val name: String, val description: String?) {
        object InvalidDeviceName: BlueCatbirdMlsRegisterDeviceError("InvalidDeviceName", "")
        object InvalidKeyPackages: BlueCatbirdMlsRegisterDeviceError("InvalidKeyPackages", "")
        object InvalidSignatureKey: BlueCatbirdMlsRegisterDeviceError("InvalidSignatureKey", "")
        object DeviceAlreadyRegistered: BlueCatbirdMlsRegisterDeviceError("DeviceAlreadyRegistered", "")
        object TooManyDevices: BlueCatbirdMlsRegisterDeviceError("TooManyDevices", "")
    }

/**
 * Register a device for multi-device MLS support. Each device gets a unique device ID and credential (did:plc:user#device-uuid). Required for proper multi-device group conversations.
 *
 * Endpoint: blue.catbird.mls.registerDevice
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.registerDevice(
input: BlueCatbirdMlsRegisterDeviceInput): ATProtoResponse<BlueCatbirdMlsRegisterDeviceOutput> {
    val endpoint = "blue.catbird.mls.registerDevice"

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
