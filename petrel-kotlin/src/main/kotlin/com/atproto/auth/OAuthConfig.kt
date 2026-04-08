package com.atproto.auth

data class OAuthConfig(
    val clientId: String,
    val redirectUri: String,
    val scope: String = "atproto transition:generic",
    val authorizationEndpoint: String? = null,
    val tokenEndpoint: String? = null
)
