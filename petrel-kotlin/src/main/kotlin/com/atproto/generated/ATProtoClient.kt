package com.atproto.client

class ATProtoClient(private val networkService: NetworkService) {
    val chat: Chat = Chat()

    inner class Chat {
        val bsky: Bsky = Bsky()

        inner class Bsky {
            val actor: Actor = Actor()

            inner class Actor {
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
            }

            val convo: Convo = Convo()

            inner class Convo {
            }

        }

    }

    val app: App = App()

    inner class App {
        val bsky: Bsky = Bsky()

        inner class Bsky {
            val actor: Actor = Actor()

            inner class Actor {
            }

            val bookmark: Bookmark = Bookmark()

            inner class Bookmark {
            }

            val unspecced: Unspecced = Unspecced()

            inner class Unspecced {
            }

            val graph: Graph = Graph()

            inner class Graph {
            }

            val video: Video = Video()

            inner class Video {
            }

            val feed: Feed = Feed()

            inner class Feed {
            }

            val labeler: Labeler = Labeler()

            inner class Labeler {
            }

            val richtext: Richtext = Richtext()

            inner class Richtext {
            }

            val embed: Embed = Embed()

            inner class Embed {
            }

            val notification: Notification = Notification()

            inner class Notification {
            }

        }

    }

    val com: Com = Com()

    inner class Com {
        val atproto: Atproto = Atproto()

        inner class Atproto {
            val repo: Repo = Repo()

            inner class Repo {
            }

            val lexicon: Lexicon = Lexicon()

            inner class Lexicon {
            }

            val identity: Identity = Identity()

            inner class Identity {
            }

            val moderation: Moderation = Moderation()

            inner class Moderation {
            }

            val temp: Temp = Temp()

            inner class Temp {
            }

            val admin: Admin = Admin()

            inner class Admin {
            }

            val server: Server = Server()

            inner class Server {
            }

            val sync: Sync = Sync()

            inner class Sync {
            }

            val label: Label = Label()

            inner class Label {
            }

        }

    }

}
