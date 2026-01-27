package com.atproto.client

import com.atproto.network.NetworkService

class ATProtoClient(val networkService: NetworkService) {
    constructor(baseUrl: String = "https://bsky.social") : this(NetworkService(baseUrl))

    fun close() {
        networkService.close()
    }

    fun setServiceDID(did: String, namespace: String) {
        networkService.setServiceDID(did, namespace)
    }

    fun getDid(): String? {
        return networkService.getDid()
    }

    val app: App = App()

    inner class App {
        val client: ATProtoClient get() = this@ATProtoClient
        val bsky: Bsky = Bsky()

        inner class Bsky {
            val client: ATProtoClient get() = this@ATProtoClient
            val video: Video = Video()

            inner class Video {
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
            val mls: Mls = Mls()

            inner class Mls {
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
