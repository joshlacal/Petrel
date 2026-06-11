package com.atproto.auth.oauth

import com.atproto.auth.token.TokenRefreshResult

enum class SessionState {
    Active,
    Expired,
    Invalid,
    None
}

class AuthenticationService(
    private val baseUrl: String
) {
    private var sessionState: SessionState = SessionState.None
    private var activeDid: String? = null

    fun getSessionState(): SessionState = sessionState

    fun getActiveDid(): String? = activeDid

    suspend fun restoreSession(): Boolean {
        return false
    }

    suspend fun startOAuthFlow(identifier: String, pdsUrl: String? = null): String {
        throw UnsupportedOperationException("OAuth flow not yet implemented")
    }

    suspend fun handleCallback(callbackUrl: String): Triple<String, String, String> {
        throw UnsupportedOperationException("OAuth callback not yet implemented")
    }

    suspend fun refreshToken(forceRefresh: Boolean = false): TokenRefreshResult? {
        return null
    }

    suspend fun logout() {
        activeDid = null
        sessionState = SessionState.None
    }
}
