package blue.catbird.petrel.core

import blue.catbird.petrel.core.types.ATIdentifier
import blue.catbird.petrel.core.types.ATProtocolDate
import blue.catbird.petrel.core.types.ATProtocolURI
import blue.catbird.petrel.core.types.CID
import blue.catbird.petrel.core.types.DID
import blue.catbird.petrel.core.types.Handle
import blue.catbird.petrel.core.types.NSID
import blue.catbird.petrel.core.types.SpaceRef
import blue.catbird.petrel.generated.AppBskyFeedGetLikesParameters
import blue.catbird.petrel.generated.AppBskyFeedGetQuotesParameters
import blue.catbird.petrel.generated.AppBskyFeedGetRepostedByParameters
import blue.catbird.petrel.generated.AppBskyNotificationGetUnreadCountParameters
import blue.catbird.petrel.generated.AppBskyNotificationListNotificationsParameters
import blue.catbird.petrel.generated.ComAtprotoAdminGetSubjectStatusParameters
import blue.catbird.petrel.generated.ComAtprotoRepoGetRecordParameters
import blue.catbird.petrel.generated.ComAtprotoSpaceGetBlobParameters
import blue.catbird.petrel.generated.ComAtprotoSyncGetBlobParameters
import blue.catbird.petrel.generated.ComAtprotoTempCheckHandleAvailabilityParameters
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * The Swift client once dropped every scalar CID and datetime query parameter, so
 * com.atproto.sync.getBlob went out without its `cid`. Kotlin encodes parameters
 * through each type's serializer instead, and only JSON primitives survive
 * [toQueryItems]; these pin the same parameters on the Kotlin side.
 */
class QueryItemsTest {
    private val cid = CID("bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a")
    private val did = DID.parse("did:plc:asdf123")
    private val postUri = ATProtocolURI("at://did:plc:asdf123/app.bsky.feed.post/3jzfcijpj2z2a")
    private val wireDate = "2026-10-01T12:34:56.789Z"

    @Test
    fun `getBlob sends both did and cid`() {
        assertEquals(
            listOf("did" to "did:plc:asdf123", "cid" to cid.value),
            ComAtprotoSyncGetBlobParameters(did = did, cid = cid).toQueryItems(),
        )
    }

    @Test
    fun `every scalar CID parameter is sent as its string`() {
        val cases = listOf(
            Triple("com.atproto.space.getBlob", "cid", ComAtprotoSpaceGetBlobParameters(
                space = SpaceRef.parse("at://did:plc:asdf123/space/com.example.group/default"),
                repo = did,
                cid = cid,
            ).toQueryItems()),
            Triple("com.atproto.repo.getRecord", "cid", ComAtprotoRepoGetRecordParameters(
                repo = ATIdentifier.parse("did:plc:asdf123"),
                collection = NSID.parse("app.bsky.feed.post"),
                rkey = "3jzfcijpj2z2a",
                cid = cid,
            ).toQueryItems()),
            Triple("app.bsky.feed.getLikes", "cid", AppBskyFeedGetLikesParameters(uri = postUri, cid = cid).toQueryItems()),
            Triple("app.bsky.feed.getQuotes", "cid", AppBskyFeedGetQuotesParameters(uri = postUri, cid = cid).toQueryItems()),
            Triple("app.bsky.feed.getRepostedBy", "cid", AppBskyFeedGetRepostedByParameters(uri = postUri, cid = cid).toQueryItems()),
            Triple("com.atproto.admin.getSubjectStatus", "blob", ComAtprotoAdminGetSubjectStatusParameters(blob = cid).toQueryItems()),
        )

        for ((endpoint, name, items) in cases) {
            assertEquals(listOf(cid.value), items.filter { it.first == name }.map { it.second }, "$endpoint.$name")
        }
    }

    @Test
    fun `every datetime parameter is sent as its wire string`() {
        val date = ATProtocolDate(wireDate)
        val cases = listOf(
            Triple("app.bsky.notification.getUnreadCount", "seenAt", AppBskyNotificationGetUnreadCountParameters(seenAt = date).toQueryItems()),
            Triple("app.bsky.notification.listNotifications", "seenAt", AppBskyNotificationListNotificationsParameters(seenAt = date).toQueryItems()),
            Triple("com.atproto.temp.checkHandleAvailability", "birthDate", ComAtprotoTempCheckHandleAvailabilityParameters(
                handle = Handle("alice.bsky.social"),
                birthDate = date,
            ).toQueryItems()),
        )

        for ((endpoint, name, items) in cases) {
            assertEquals(listOf(wireDate), items.filter { it.first == name }.map { it.second }, "$endpoint.$name")
        }
    }
}
