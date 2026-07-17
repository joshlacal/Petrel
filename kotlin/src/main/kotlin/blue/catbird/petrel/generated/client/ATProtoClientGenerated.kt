package blue.catbird.petrel.client

import blue.catbird.petrel.auth.OAuthConfig
import blue.catbird.petrel.auth.oauth.AuthenticationService
import blue.catbird.petrel.auth.token.TokenRefreshResult
import blue.catbird.petrel.network.NetworkService

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

    // -- Gateway session management (LEGACY) --
    //
    // These inline helpers pre-date `ConfidentialGatewayStrategy`. They are
    // preserved for source compatibility only; new code should call
    // `ATProtoClient.configureGateway(...)` and use the strategy-backed
    // extensions in `ATProtoClientGatewayExt.kt` instead.
    //
    // In particular, `handleGatewayCallback` here parses `did`/`handle` out
    // of the URL fragment — but nest only puts `session_id` in the fragment,
    // so those values end up empty. The strategy fetches the canonical
    // `did`/`handle` via `GET {gateway}/auth/session` and is the correct path.

    @Deprecated(
        "Use ATProtoClient.configureGateway(...) and the strategy API in ATProtoClientGatewayExt.kt",
        ReplaceWith("gatewayRestoreSession(did)"),
    )
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

    @Deprecated(
        "Use ATProtoClient.configureGateway(...) and the strategy API in ATProtoClientGatewayExt.kt",
    )
    fun clearGatewaySession() {
        gatewaySession = null
        networkService.authenticatedDID = null
        networkService.authorizationHeader = null
    }

    @Deprecated(
        "Use ATProtoClient.configureGateway(...) and the strategy API in ATProtoClientGatewayExt.kt",
    )
    fun currentGatewaySessionId(): String? = gatewaySession?.sessionId

    fun getActiveDid(): String? {
        return gatewaySession?.did ?: authService?.getActiveDid()
    }

    // -- Gateway login flow (LEGACY) --

    @Deprecated(
        "Use ConfidentialGatewayStrategy.startOAuthFlow via ATProtoClient.configureGateway(...)",
        ReplaceWith("gatewayStartOAuthFlow(identifier)"),
    )
    fun createGatewayLoginUrl(identifier: String? = null): String {
        val base = "${networkService.getBaseUrl()}/auth/login"
        return if (identifier != null) {
            "$base?identifier=${java.net.URLEncoder.encode(identifier, "UTF-8")}"
        } else {
            base
        }
    }

    @Deprecated(
        "Disabled: URL-carried session credentials are unsafe. Use " +
            "ATProtoClient.configureGateway(...) + gatewayHandleCallback(url).",
        ReplaceWith("gatewayHandleCallback(callbackUrl)"),
    )
    fun handleGatewayCallback(callbackUrl: String): GatewaySessionInfo {
        throw UnsupportedOperationException(
            "Legacy gateway callbacks are disabled; use the single-use exchange flow",
        )
    }

    @Deprecated(
        "Wrong endpoint: hits /xrpc//auth/logout because NetworkService prepends /xrpc. " +
            "Use ATProtoClient.configureGateway(...) + gatewayLogoutViaStrategy().",
        ReplaceWith("gatewayLogoutViaStrategy()"),
    )
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
            val authCreatePosts: AuthCreatePosts = AuthCreatePosts()

            @Deprecated("Renamed", ReplaceWith("authCreatePosts"))
            val authcreateposts: AuthCreatePosts get() = authCreatePosts

            inner class AuthCreatePosts {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authDeleteContent: AuthDeleteContent = AuthDeleteContent()

            @Deprecated("Renamed", ReplaceWith("authDeleteContent"))
            val authdeletecontent: AuthDeleteContent get() = authDeleteContent

            inner class AuthDeleteContent {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authFullApp: AuthFullApp = AuthFullApp()

            @Deprecated("Renamed", ReplaceWith("authFullApp"))
            val authfullapp: AuthFullApp get() = authFullApp

            inner class AuthFullApp {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authManageFeedDeclarations: AuthManageFeedDeclarations = AuthManageFeedDeclarations()

            @Deprecated("Renamed", ReplaceWith("authManageFeedDeclarations"))
            val authmanagefeeddeclarations: AuthManageFeedDeclarations get() = authManageFeedDeclarations

            inner class AuthManageFeedDeclarations {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authManageLabelerService: AuthManageLabelerService = AuthManageLabelerService()

            @Deprecated("Renamed", ReplaceWith("authManageLabelerService"))
            val authmanagelabelerservice: AuthManageLabelerService get() = authManageLabelerService

            inner class AuthManageLabelerService {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authManageModeration: AuthManageModeration = AuthManageModeration()

            @Deprecated("Renamed", ReplaceWith("authManageModeration"))
            val authmanagemoderation: AuthManageModeration get() = authManageModeration

            inner class AuthManageModeration {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authManageNotifications: AuthManageNotifications = AuthManageNotifications()

            @Deprecated("Renamed", ReplaceWith("authManageNotifications"))
            val authmanagenotifications: AuthManageNotifications get() = authManageNotifications

            inner class AuthManageNotifications {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authManageProfile: AuthManageProfile = AuthManageProfile()

            @Deprecated("Renamed", ReplaceWith("authManageProfile"))
            val authmanageprofile: AuthManageProfile get() = authManageProfile

            inner class AuthManageProfile {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val authViewAll: AuthViewAll = AuthViewAll()

            @Deprecated("Renamed", ReplaceWith("authViewAll"))
            val authviewall: AuthViewAll get() = authViewAll

            inner class AuthViewAll {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val actor: Actor = Actor()

            inner class Actor {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val ageassurance: Ageassurance = Ageassurance()

            inner class Ageassurance {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val bookmark: Bookmark = Bookmark()

            inner class Bookmark {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val contact: Contact = Contact()

            inner class Contact {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val draft: Draft = Draft()

            inner class Draft {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val embed: Embed = Embed()

            inner class Embed {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val feed: Feed = Feed()

            inner class Feed {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val graph: Graph = Graph()

            inner class Graph {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val labeler: Labeler = Labeler()

            inner class Labeler {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val notification: Notification = Notification()

            inner class Notification {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val richtext: Richtext = Richtext()

            inner class Richtext {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val unspecced: Unspecced = Unspecced()

            inner class Unspecced {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val video: Video = Video()

            inner class Video {
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
            val authFullChatClient: AuthFullChatClient = AuthFullChatClient()

            @Deprecated("Renamed", ReplaceWith("authFullChatClient"))
            val authfullchatclient: AuthFullChatClient get() = authFullChatClient

            inner class AuthFullChatClient {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val actor: Actor = Actor()

            inner class Actor {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val convo: Convo = Convo()

            inner class Convo {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val embed: Embed = Embed()

            inner class Embed {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val group: Group = Group()

            inner class Group {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val notification: Notification = Notification()

            inner class Notification {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }

    val com: Com = Com()

    inner class Com {
        val client: ATProtoClient get() = this@ATProtoClient
        val atproto: Atproto = Atproto()

        inner class Atproto {
            val client: ATProtoClient get() = this@ATProtoClient
            val admin: Admin = Admin()

            inner class Admin {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val identity: Identity = Identity()

            inner class Identity {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val label: Label = Label()

            inner class Label {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val lexicon: Lexicon = Lexicon()

            inner class Lexicon {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val repo: Repo = Repo()

            inner class Repo {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val server: Server = Server()

            inner class Server {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val sync: Sync = Sync()

            inner class Sync {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val temp: Temp = Temp()

            inner class Temp {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

        val germnetwork: Germnetwork = Germnetwork()

        inner class Germnetwork {
            val client: ATProtoClient get() = this@ATProtoClient
            val declaration: Declaration = Declaration()

            inner class Declaration {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }

    val site: Site = Site()

    inner class Site {
        val client: ATProtoClient get() = this@ATProtoClient
        val standard: Standard = Standard()

        inner class Standard {
            val client: ATProtoClient get() = this@ATProtoClient
            val document: Document = Document()

            inner class Document {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val publication: Publication = Publication()

            inner class Publication {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val graph: Graph = Graph()

            inner class Graph {
                val client: ATProtoClient get() = this@ATProtoClient
            }

            val theme: Theme = Theme()

            inner class Theme {
                val client: ATProtoClient get() = this@ATProtoClient
            }

        }

    }


}