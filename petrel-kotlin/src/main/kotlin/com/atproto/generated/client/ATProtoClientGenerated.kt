package com.atproto.client

import com.atproto.auth.OAuthConfig
import com.atproto.auth.oauth.AuthenticationService
import com.atproto.auth.token.TokenRefreshResult
import com.atproto.network.NetworkService

class ATProtoClient(val networkService: NetworkService) {
    constructor(baseUrl: String = "https://bsky.social") : this(NetworkService(baseUrl))

    private var authMode: AuthMode = AuthMode.Gateway
    private var gatewaySession: GatewaySessionInfo? = null
    var authService: AuthenticationService? = null
        private set

    fun close() {
        networkService.close()
    }

    fun setServiceDID(did: String, namespace: String) {
        networkService.setServiceDID(did, namespace)
    }

    fun getDid(): String? {
        return networkService.getDid()
    }

    // -- Auth mode --

    fun setAuthMode(mode: AuthMode) {
        authMode = mode
    }

    fun getAuthMode(): AuthMode = authMode

    // -- Gateway session management --

    fun restoreGatewaySession(
        sessionId: String,
        did: String,
        handle: String?,
        active: Boolean? = null
    ): GatewaySessionInfo {
        val session = GatewaySessionInfo(
            sessionId = sessionId,
            did = did,
            handle = handle,
            active = active
        )
        gatewaySession = session
        networkService.authenticatedDID = did
        networkService.authorizationHeader = "Bearer $sessionId"
        authMode = AuthMode.Gateway
        return session
    }

    fun clearGatewaySession() {
        gatewaySession = null
        networkService.authenticatedDID = null
        networkService.authorizationHeader = null
    }

    fun currentGatewaySessionId(): String? = gatewaySession?.sessionId

    fun getActiveDid(): String? {
        return gatewaySession?.did ?: authService?.getActiveDid()
    }

    // -- Gateway login flow --

    fun createGatewayLoginUrl(identifier: String? = null): String {
        val base = "${networkService.getBaseUrl()}/auth/login"
        return if (identifier != null) {
            "$base?identifier=${java.net.URLEncoder.encode(identifier, "UTF-8")}"
        } else {
            base
        }
    }

    fun handleGatewayCallback(callbackUrl: String): GatewaySessionInfo {
        val fragment = callbackUrl.substringAfter("#", "")
        val params = fragment.split("&").associate { part ->
            val (key, value) = part.split("=", limit = 2)
            key to java.net.URLDecoder.decode(value, "UTF-8")
        }

        val sessionId = params["session_id"]
            ?: throw IllegalArgumentException("Gateway callback missing session_id")

        val session = GatewaySessionInfo(
            sessionId = sessionId,
            did = params["did"] ?: "",
            handle = params["handle"]
        )
        gatewaySession = session
        networkService.authenticatedDID = session.did
        networkService.authorizationHeader = "Bearer $sessionId"
        authMode = AuthMode.Gateway
        return session
    }

    suspend fun gatewayLogout() {
        val sessionId = gatewaySession?.sessionId ?: return
        networkService.performRequest<Unit>(
            method = "POST",
            endpoint = "/auth/logout",
            headers = mapOf("Authorization" to "Bearer $sessionId")
        )
        clearGatewaySession()
    }

    // -- OAuth flow (delegated to AuthenticationService) --

    fun configureOAuth(config: OAuthConfig) {
        authService = AuthenticationService(
            baseUrl = config.authorizationEndpoint ?: networkService.getBaseUrl()
        )
        authMode = AuthMode.OAuth
    }

    suspend fun startOAuthFlow(identifier: String, pdsUrl: String? = null): String {
        val service = authService
            ?: throw IllegalStateException("OAuth not configured; call configureOAuth first")
        return service.startOAuthFlow(identifier, pdsUrl)
    }

    suspend fun handleOAuthCallback(callbackUrl: String): Triple<String, String, String> {
        val service = authService
            ?: throw IllegalStateException("OAuth not configured")
        return service.handleCallback(callbackUrl)
    }

    suspend fun refreshOAuthToken(forceRefresh: Boolean = false): TokenRefreshResult? {
        return authService?.refreshToken(forceRefresh)
    }

    // MARK: - Generated API Namespace Classes

    val app: App = App()

    inner class App {
        val client: ATProtoClient get() = this@ATProtoClient
        val bsky: Bsky = Bsky()

        inner class Bsky {
            val client: ATProtoClient get() = this@ATProtoClient
            val authmanagelabelerservice: AuthManageLabelerService = AuthManageLabelerService()

            inner class AuthManageLabelerService {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authmanagenotifications: AuthManageNotifications = AuthManageNotifications()

            inner class AuthManageNotifications {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authdeletecontent: AuthDeleteContent = AuthDeleteContent()

            inner class AuthDeleteContent {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authcreateposts: AuthCreatePosts = AuthCreatePosts()

            inner class AuthCreatePosts {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authfullapp: AuthFullApp = AuthFullApp()

            inner class AuthFullApp {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authmanagemoderation: AuthManageModeration = AuthManageModeration()

            inner class AuthManageModeration {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authviewall: AuthViewAll = AuthViewAll()

            inner class AuthViewAll {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authmanagefeeddeclarations: AuthManageFeedDeclarations = AuthManageFeedDeclarations()

            inner class AuthManageFeedDeclarations {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authmanageprofile: AuthManageProfile = AuthManageProfile()

            inner class AuthManageProfile {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val draft: Draft = Draft()

            inner class Draft {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val video: Video = Video()

            inner class Video {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val contact: Contact = Contact()

            inner class Contact {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val bookmark: Bookmark = Bookmark()

            inner class Bookmark {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val embed: Embed = Embed()

            inner class Embed {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val notification: Notification = Notification()

            inner class Notification {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val unspecced: Unspecced = Unspecced()

            inner class Unspecced {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val graph: Graph = Graph()

            inner class Graph {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val feed: Feed = Feed()

            inner class Feed {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val richtext: Richtext = Richtext()

            inner class Richtext {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val ageassurance: Ageassurance = Ageassurance()

            inner class Ageassurance {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val actor: Actor = Actor()

            inner class Actor {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val labeler: Labeler = Labeler()

            inner class Labeler {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }

    val chat: Chat = Chat()

    inner class Chat {
        val client: ATProtoClient get() = this@ATProtoClient
        val bsky: Bsky = Bsky()

        inner class Bsky {
            val client: ATProtoClient get() = this@ATProtoClient
            val authfullchatclient: AuthFullChatClient = AuthFullChatClient()

            inner class AuthFullChatClient {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val convo: Convo = Convo()

            inner class Convo {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val actor: Actor = Actor()

            inner class Actor {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }

    val blue: Blue = Blue()

    inner class Blue {
        val client: ATProtoClient get() = this@ATProtoClient
        val catbird: Catbird = Catbird()

        inner class Catbird {
            val client: ATProtoClient get() = this@ATProtoClient
            val mlschat: MlsChat = MlsChat()

            inner class MlsChat {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val bskychat: Bskychat = Bskychat()

            inner class Bskychat {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val mlsds: MlsDS = MlsDS()

            inner class MlsDS {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }

    val place: Place = Place()

    inner class Place {
        val client: ATProtoClient get() = this@ATProtoClient
        val stream: Stream = Stream()

        inner class Stream {
            val client: ATProtoClient get() = this@ATProtoClient
            val defs: Defs = Defs()

            inner class Defs {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val livestream: Livestream = Livestream()

            inner class Livestream {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val key: Key = Key()

            inner class Key {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val video: Video = Video()

            inner class Video {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val segment: Segment = Segment()

            inner class Segment {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val branding: Branding = Branding()

            inner class Branding {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val chat: Chat = Chat()

            inner class Chat {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val config: Config = Config()

            inner class Config {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val multistream: Multistream = Multistream()

            inner class Multistream {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val ingest: Ingest = Ingest()

            inner class Ingest {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val graph: Graph = Graph()

            inner class Graph {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val server: Server = Server()

            inner class Server {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val playback: Playback = Playback()

            inner class Playback {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val live: Live = Live()

            inner class Live {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val richtext: Richtext = Richtext()

            inner class Richtext {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val muxl: Muxl = Muxl()

            inner class Muxl {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val metadata: Metadata = Metadata()

            inner class Metadata {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val broadcast: Broadcast = Broadcast()

            inner class Broadcast {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val badge: Badge = Badge()

            inner class Badge {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }

    val com: Com = Com()

    inner class Com {
        val client: ATProtoClient get() = this@ATProtoClient
        val germnetwork: Germnetwork = Germnetwork()

        inner class Germnetwork {
            val client: ATProtoClient get() = this@ATProtoClient
            val declaration: Declaration = Declaration()

            inner class Declaration {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

        val atproto: Atproto = Atproto()

        inner class Atproto {
            val client: ATProtoClient get() = this@ATProtoClient
            val temp: Temp = Temp()

            inner class Temp {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val identity: Identity = Identity()

            inner class Identity {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val admin: Admin = Admin()

            inner class Admin {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val label: Label = Label()

            inner class Label {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val server: Server = Server()

            inner class Server {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val lexicon: Lexicon = Lexicon()

            inner class Lexicon {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val sync: Sync = Sync()

            inner class Sync {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val repo: Repo = Repo()

            inner class Repo {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }


}