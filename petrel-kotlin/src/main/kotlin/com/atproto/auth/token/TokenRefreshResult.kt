package com.atproto.auth.token

data class TokenRefreshResult(
    val accessToken: String,
    val refreshToken: String? = null,
    val expiresIn: Long? = null,
    val didRefresh: Boolean = false
)
