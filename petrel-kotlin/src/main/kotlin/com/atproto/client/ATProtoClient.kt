package com.atproto.client

import com.atproto.network.NetworkService

/**
 * Main AT Protocol client for interacting with the AT Protocol APIs.
 *
 * Usage:
 * ```
 * val client = ATProtoClient("https://bsky.social")
 * val profile = client.app.bsky.actor.getProfile(...)
 * ```
 */
class ATProtoClient(
    baseUrl: String = "https://bsky.social"
) {
    internal val networkService = NetworkService(baseUrl)

    // Namespace classes will be generated here by the code generator

    fun close() {
        networkService.close()
    }
}
