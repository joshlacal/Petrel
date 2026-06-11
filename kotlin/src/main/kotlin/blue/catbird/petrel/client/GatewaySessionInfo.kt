package blue.catbird.petrel.client

data class GatewaySessionInfo(
    val sessionId: String,
    val did: String,
    val handle: String?,
    val active: Boolean? = null
)
