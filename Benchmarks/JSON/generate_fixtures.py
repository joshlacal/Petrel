#!/usr/bin/env python3
"""Generate public, deterministic Petrel JSON benchmark fixtures (stdlib only).

No network requests or real account data are used. Run from any directory.
Byte hashes deliberately include the trailing newline written to each JSON file.
"""

from __future__ import annotations

import base64
import hashlib
import json
from functools import lru_cache
from pathlib import Path

SEED = 20260930
ROOT = Path(__file__).resolve().parent
OUT = ROOT / "Fixtures"
UNICODE = "鳥と空 🐦 🌏 東京の朝、你好，世界！ 안녕하세요 café cafe\u0301 👩🏽‍💻 👨‍👩‍👧‍👦 العربية שלום"


def encoded(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def cid(index: int, raw: bool = False) -> str:
    """Valid CIDv1 + dag-cbor/raw codec + sha256 multihash, synthetic digest."""
    prefix = bytes([1, 0x55 if raw else 0x71, 0x12, 0x20])
    digest = hashlib.sha256(f"petrel-benchmark:{SEED}:{index}".encode()).digest()
    return "b" + base64.b32encode(prefix + digest).decode().lower().rstrip("=")


def did(index: int) -> str:
    # PLC IDs have a 24-character lower-case base32 suffix.
    digest = hashlib.sha256(f"synthetic-actor:{SEED}:{index}".encode()).digest()
    return "did:plc:" + base64.b32encode(digest).decode().lower()[:24]


def aturi(index: int, collection: str = "app.bsky.feed.post") -> str:
    return f"at://{did(index % 73)}/{collection}/bench{index:09d}"


def date(index: int) -> str:
    fractions = ["000", "123456", "720942844"]
    return f"2026-09-{1 + index % 28:02d}T{index % 24:02d}:{index % 60:02d}:{(index * 7) % 60:02d}.{fractions[index % 3]}Z"


def label(index: int) -> dict:
    return {"ver": 1, "src": did(900), "uri": aturi(index), "cid": cid(index),
            "val": "benchmark-label", "neg": False, "cts": date(index)}


def actor(index: int, unicode: bool = False, detailed: bool = False) -> dict:
    value = {
        "did": did(index), "handle": f"actor{index}.example.test",
        "displayName": f"{UNICODE if unicode else 'Synthetic birdwatcher'} {index}",
        "avatar": f"https://images.example.test/avatar/{index}/{cid(index, True)}.jpg",
        "associated": {"lists": index % 5, "feedgens": index % 3, "starterPacks": index % 2,
                       "labeler": False, "chat": {"allowIncoming": "following"}},
        "viewer": {"muted": False, "blockedBy": False,
                   "following": aturi(index, "app.bsky.graph.follow")},
        "labels": [], "createdAt": date(index),
    }
    if detailed:
        value.update({"description": f"{UNICODE if unicode else 'A synthetic profile for repeatable decoding benchmarks.'}\nBirds, photography, software, and science.",
                      "banner": f"https://images.example.test/banner/{index}.jpg",
                      "website": "https://example.test/about", "pronouns": "they/them",
                      "followersCount": 1421, "followsCount": 307, "postsCount": 8203,
                      "indexedAt": date(index + 1),
                      "pinnedPost": {"uri": aturi(index), "cid": cid(index)}})
    return value


def facet(text: str, token: str, feature: dict) -> dict:
    start = text.index(token)
    return {"index": {"byteStart": len(text[:start].encode()),
                      "byteEnd": len(text[:start + len(token)].encode())},
            "features": [feature]}


def blob(index: int) -> dict:
    return {"$type": "blob", "ref": {"$link": cid(index, True)},
            "mimeType": "image/jpeg", "size": 327000 + index % 7000}


def image_embeds(index: int, unicode: bool = False) -> tuple[dict, dict]:
    record_images, view_images = [], []
    for offset in range(1 + index % 4):
        alt = f"{UNICODE if unicode else 'A small bird perched on a branch near the water.'} Photo {offset + 1}."
        ratio = {"width": 1200 + offset * 10, "height": 800}
        record_images.append({"alt": alt, "aspectRatio": ratio, "image": blob(index * 4 + offset)})
        view_images.append({"alt": alt, "aspectRatio": ratio,
                            "thumb": f"https://images.example.test/feed/thumbnail/{cid(index * 4 + offset, True)}.jpg",
                            "fullsize": f"https://images.example.test/feed/fullsize/{cid(index * 4 + offset, True)}.jpg"})
    return ({"$type": "app.bsky.embed.images", "images": record_images},
            {"$type": "app.bsky.embed.images#view", "images": view_images})


def external_embeds(index: int, unicode: bool = False) -> tuple[dict, dict]:
    external = {"uri": f"https://example.test/articles/{index}?source=feed&lang=en",
                "title": f"Field notes {index}: {UNICODE if unicode else 'A morning by the lake'}",
                "description": UNICODE if unicode else "A synthetic article description with enough text to represent a normal link card.\nIncludes escaped newlines and \"quoted\" text."}
    record = dict(external, thumb=blob(index + 90000))
    view = dict(external, thumb=f"https://images.example.test/cards/{index}.jpg")
    return ({"$type": "app.bsky.embed.external", "external": record},
            {"$type": "app.bsky.embed.external#view", "external": view})


def plain_record(index: int, unicode: bool = False) -> dict:
    prefix = (UNICODE + "\n") if unicode else "A morning at the lake: birds, light, and a few field notes.\n"
    text = f"{prefix}@actor7.example.test https://example.test/notes/{index} #Birds"
    return {"$type": "app.bsky.feed.post", "text": text, "createdAt": date(index),
            "langs": ["en", "ja"] if unicode else ["en"], "tags": ["Birds", "nature"],
            "facets": [facet(text, "@actor7.example.test", {"$type": "app.bsky.richtext.facet#mention", "did": did(7)}),
                       facet(text, f"https://example.test/notes/{index}", {"$type": "app.bsky.richtext.facet#link", "uri": f"https://example.test/notes/{index}"}),
                       facet(text, "#Birds", {"$type": "app.bsky.richtext.facet#tag", "tag": "Birds"})]}


def quote_embeds(index: int, unicode: bool = False) -> tuple[dict, dict]:
    quoted = index + 100000
    return ({"$type": "app.bsky.embed.record", "record": {"uri": aturi(quoted), "cid": cid(quoted)}},
            {"$type": "app.bsky.embed.record#view", "record": {
                "$type": "app.bsky.embed.record#viewRecord", "uri": aturi(quoted), "cid": cid(quoted),
                "author": actor(quoted % 73, unicode), "value": plain_record(quoted, unicode),
                "indexedAt": date(quoted), "labels": [], "replyCount": 3,
                "repostCount": 5, "likeCount": 11, "quoteCount": 1,
                "embeds": [external_embeds(quoted, unicode)[1]]}})


def post(index: int, unicode: bool = False, with_embed: bool = True) -> dict:
    record = plain_record(index, unicode)
    value = {"$type": "app.bsky.feed.defs#postView", "uri": aturi(index), "cid": cid(index),
             "author": actor(index % 73, unicode), "record": record, "indexedAt": date(index + 1),
             "replyCount": index % 31, "repostCount": index % 87, "likeCount": index % 293,
             "quoteCount": index % 17, "bookmarkCount": index % 9,
             "viewer": {"bookmarked": index % 13 == 0, "threadMuted": False,
                        "replyDisabled": False, "embeddingDisabled": False,
                        "like": aturi(index, "app.bsky.feed.like")},
             "labels": [label(index)] if index % 11 == 0 else []}
    if with_embed:
        kind = index % 5
        if kind == 0:
            record["embed"], value["embed"] = image_embeds(index, unicode)
        elif kind == 1:
            record["embed"], value["embed"] = external_embeds(index, unicode)
        elif kind == 2:
            record["embed"], value["embed"] = quote_embeds(index, unicode)
        elif kind == 3:
            quoted_record, quoted_view = quote_embeds(index, unicode)
            media_record, media_view = image_embeds(index, unicode)
            record["embed"] = {"$type": "app.bsky.embed.recordWithMedia", "record": quoted_record, "media": media_record}
            value["embed"] = {"$type": "app.bsky.embed.recordWithMedia#view", "record": quoted_view, "media": media_view}
    return value


def feed_item(index: int, unicode: bool = False, difficult: bool = False) -> dict:
    value = {"post": post(index, unicode), "feedContext": f"synthetic-ranking-context-{index % 17}",
             "reqId": f"benchmark-{index:09d}"}
    if index % 4 == 0:
        root, parent = index + 200000, index + 300000
        value["post"]["record"]["reply"] = {
            "root": {"uri": aturi(root), "cid": cid(root)},
            "parent": {"uri": aturi(parent), "cid": cid(parent)}}
        value["reply"] = {"root": post(root, unicode, False), "parent": post(parent, unicode, False),
                          "grandparentAuthor": actor(root % 73, unicode)}
    if index % 6 == 0:
        value["reason"] = {"$type": "app.bsky.feed.defs#reasonRepost", "by": actor((index + 1) % 73, unicode),
                           "uri": aturi(index, "app.bsky.feed.repost"), "cid": cid(index + 400000), "indexedAt": date(index + 2)}
    if difficult:
        value["post"]["debug"] = {
            "$type": "test.example.benchmark#debug", "rank": index,
            "flags": [True, False, None], "dictionary": {f"field{k}": {"index": k, "items": ["hello", index, {"x": "y"}]} for k in range(6)},
            "link": {"$link": cid(index)}, "nullable": None,
            "nested": [{"a": [{"b": [{"c": "depth"}]}]}]}
        # These exercise normal forward compatibility, not invalid syntax.
        value["post"]["record"]["via"] = "Synthetic Benchmark Client"
        value["post"]["record"]["unknownFutureField"] = {"array": [1, None, "three"]}
        if index % 3 == 0:
            value["post"]["embed"] = {"$type": "test.example.futureEmbed#view", "title": UNICODE,
                                       "items": [{"uri": "https://example.test/future", "hints": [True, None, 12]}]}
        if index % 7 == 0:
            value["reason"] = {"$type": "test.example.futureReason", "scores": [1, 2, 3], "source": {"name": "future"}}
        if index % 5 == 0:
            value["post"]["record"] = {"$type": "test.example.futureRecord", "text": UNICODE,
                                        "createdAt": date(index), "settings": {"enabled": True, "tags": ["x", "y"], "empty": {}}}
        if index % 2 == 0:
            value["post"]["bookmarkCount"] = None
            value["post"]["record"]["unusedOptional"] = None
    return value


def timeline(count: int, unicode: bool = False, difficult: bool = False) -> dict:
    return {"cursor": f"2026-09-01T00:00:00.000Z::{count}",
            "feed": [feed_item(i, unicode, difficult) for i in range(count)]}


# Wire-fidelity edge cases. Each URI is valid on the wire but was normalized by the
# legacy URI decoder (ports, userinfo, percent-escapes and non-ASCII text were lost
# or rewritten on re-encode), which demoted the enclosing record to unknownType.
# Whitespace-padded URIs stay demoted by design: decoding trims them.
FIDELITY_EDGE_URIS = [
    ("clean", "https://example.test/notes/{i}"),
    ("port", "https://example.test:8443/notes/{i}"),
    ("userinfo", "https://reader@example.test/notes/{i}"),
    ("userinfo-password-port-query-fragment", "https://reader:secret@example.test:8080/notes/{i}?a=1#top"),
    ("empty-port", "https://example.test:/notes/{i}"),
    ("ipv6-port", "https://[2001:db8::1]:8443/notes/{i}"),
    ("non-ascii-path", "https://ja.wikipedia.org/wiki/\u65e5\u672c\u8a9e_{i}"),
    ("latin1-path", "https://example.test/caf\u00e9/{i}"),
    ("emoji-path", "https://example.test/\U0001f426/{i}"),
    ("idn-host", "https://b\u00fccher.example/notes/{i}"),
    ("punycode-host", "https://xn--bcher-kva.example/notes/{i}"),
    ("pct-2F", "https://example.test/a%2Fb/{i}"),
    ("pct-26-query", "https://example.test/search?q=a%26b&n={i}"),
    ("pct-lowercase-hex", "https://example.test/q?x=%e6%97%a5&n={i}"),
    ("mailto", "mailto:birds{i}@example.test"),
    ("uppercase-scheme-host", "HTTPS://EXAMPLE.test/Notes/{i}"),
    ("whitespace-padded", "  https://example.test/notes/{i}  "),
    ("trailing-newline", "https://example.test/notes/{i}\n"),
]
FIDELITY_PADDED = {"whitespace-padded", "trailing-newline"}


def legacy_blob(index: int) -> dict:
    return {"cid": cid(index, True), "mimeType": "image/jpeg"}


def edge_uri(slot: int, index: int) -> tuple[str, str]:
    name, template = FIDELITY_EDGE_URIS[slot % len(FIDELITY_EDGE_URIS)]
    return name, template.format(i=index)


def set_link_facet(record: dict, uri: str) -> None:
    links = [f for f in record["facets"] if f["features"][0]["$type"] == "app.bsky.richtext.facet#link"]
    assert len(links) == 1
    links[0]["features"][0]["uri"] = uri


def legacy_images(embed: dict, index: int, first_only: bool) -> None:
    images = embed["images"] if embed["$type"] == "app.bsky.embed.images" else embed["media"]["images"]
    for offset, image in enumerate(images):
        if offset == 0 or not first_only:
            image["image"] = legacy_blob(700000 + index * 4 + offset)


def fidelity_edge_item(index: int) -> dict:
    item = feed_item(index)
    post_view = item["post"]
    record = post_view["record"]
    facet_name, facet_uri = edge_uri(index, index)
    set_link_facet(record, facet_uri)
    external_name, blob_kind = "-", "-"
    if index % 2 == 0:
        external_name, uri = edge_uri(index // 2, index)
        record_embed, view_embed = external_embeds(index)
        record_embed["external"]["uri"] = uri
        view_embed["external"]["uri"] = uri
        record["embed"], post_view["embed"] = record_embed, view_embed
    elif index % 4 == 1:
        record_embed, view_embed = image_embeds(index)
        legacy_images(record_embed, index, first_only=False)
        record["embed"], post_view["embed"] = record_embed, view_embed
        blob_kind = "legacy"
    elif record.get("embed", {}).get("$type") in ("app.bsky.embed.images", "app.bsky.embed.recordWithMedia"):
        legacy_images(record["embed"], index, first_only=True)
        blob_kind = "mixed"
    if "reply" in item:
        reply_name, reply_uri = edge_uri(index + 9, index)
        set_link_facet(item["reply"]["parent"]["record"], reply_uri)
    else:
        reply_name = "-"
    item["feedContext"] = f"fidelity-edge facet={facet_name} external={external_name} blob={blob_kind} replyParentFacet={reply_name}"
    return item


def record_has_padded_uri(record: dict) -> bool:
    uris = [f["features"][0].get("uri") for f in record.get("facets", [])]
    embed = record.get("embed", {})
    if embed.get("$type") == "app.bsky.embed.external":
        uris.append(embed["external"]["uri"])
    return any(isinstance(u, str) and u != u.strip() for u in uris)


def fidelity_edge_timeline(count: int) -> dict:
    return {"cursor": f"2026-09-01T00:00:00.000Z::fidelity-edge::{count}",
            "feed": [fidelity_edge_item(i) for i in range(count)]}


def base64_records() -> tuple[dict, bytes]:
    # 32 KiB each, deterministic incompressible-looking content. Real $bytes
    # representation used by Petrel's dynamic IPLD path, synthetic application.
    raw = b"".join(hashlib.sha256(f"bytes:{SEED}:{i}".encode()).digest() for i in range(1024))
    b64 = base64.b64encode(raw).decode()
    records = [{"uri": aturi(i, "test.example.binary"), "cid": cid(i), "value": {
        "$type": "test.example.binary", "name": f"Synthetic binary record {i}",
        "createdAt": date(i), "payload": {"$bytes": b64},
        "metadata": {"encoding": "opaque", "length": len(raw), "tags": ["benchmark", "synthetic"]}}} for i in range(32)]
    return {"cursor": "synthetic-binary-page-2", "records": records}, raw


def count_nodes(value: object) -> int:
    if isinstance(value, dict):
        return 1 + sum(count_nodes(v) for v in value.values())
    if isinstance(value, list):
        return 1 + sum(count_nodes(v) for v in value)
    return 1


def check_facets(value: object) -> None:
    if isinstance(value, dict):
        if value.get("$type") == "app.bsky.feed.post":
            text = value["text"].encode()
            for item in value.get("facets", []):
                start, end = item["index"]["byteStart"], item["index"]["byteEnd"]
                assert 0 <= start <= end <= len(text)
                text[start:end].decode("utf-8")
        for child in value.values():
            check_facets(child)
    elif isinstance(value, list):
        for child in value:
            check_facets(child)


@lru_cache(maxsize=None)
def lexicon(identifier: str) -> dict:
    return json.loads((ROOT.parent.parent / "generator" / "lexicons" / (identifier.replace(".", "/") + ".json")).read_text())


def check_schema(value: object, schema: dict, namespace: str, path: str = "$", optional: bool = False) -> None:
    """Check required fields/shapes and known references against vendored schemas.

    This is a fixture sanity check, not a replacement for Petrel differential
    decoding: it intentionally allows unknown union members and extra fields.
    Grapheme and full semantic format validation remain Petrel's responsibility.
    """
    if value is None and optional:
        return
    kind = schema["type"]
    if kind == "ref":
        target = schema["ref"]
        target_namespace, _, name = target.partition("#")
        target_namespace = target_namespace or namespace
        check_schema(value, lexicon(target_namespace)["defs"][name or "main"], target_namespace, path)
    elif kind == "record":
        check_schema(value, schema["record"], namespace, path)
    elif kind == "object":
        assert isinstance(value, dict), (path, kind)
        for required in schema.get("required", []):
            assert required in value and value[required] is not None, (path, required)
        for key, child in schema.get("properties", {}).items():
            if key in value:
                check_schema(value[key], child, namespace, path + "." + key, key not in schema.get("required", []))
    elif kind == "array":
        assert isinstance(value, list), (path, kind)
        assert len(value) <= schema.get("maxLength", 2**63), (path, "maxLength")
        for index, child in enumerate(value):
            check_schema(child, schema["items"], namespace, f"{path}[{index}]")
    elif kind == "union":
        assert isinstance(value, dict) and isinstance(value.get("$type"), str), (path, kind)
        tag = value["$type"]
        allowed = [namespace + ref if ref.startswith("#") else ref for ref in schema["refs"]]
        if tag in allowed:
            check_schema(value, {"type": "ref", "ref": tag}, namespace, path)
        else:
            assert not schema.get("closed", False), (path, "closed union")
    elif kind == "unknown":
        if isinstance(value, dict) and isinstance(value.get("$type"), str):
            namespace_candidate = value["$type"].split("#")[0]
            candidate_path = ROOT.parent.parent / "generator" / "lexicons" / (namespace_candidate.replace(".", "/") + ".json")
            if candidate_path.exists():
                check_schema(value, {"type": "ref", "ref": value["$type"]}, namespace, path)
    elif kind == "string":
        assert isinstance(value, str), (path, kind)
        assert len(value.encode()) <= schema.get("maxLength", 2**63), (path, "maxLength")
    elif kind == "integer":
        assert isinstance(value, int) and not isinstance(value, bool), (path, kind)
        assert schema.get("minimum", -(2**63)) <= value <= schema.get("maximum", 2**63 - 1), path
    elif kind == "boolean":
        assert isinstance(value, bool), (path, kind)
    elif kind == "blob":
        if isinstance(value, dict) and "$type" not in value and set(value) == {"cid", "mimeType"}:
            # Legacy (2023-era) blob shape {cid, mimeType}; still accepted by the spec's readers.
            assert isinstance(value["cid"], str) and isinstance(value["mimeType"], str), path
            return
        assert isinstance(value, dict) and value.get("$type") == "blob", (path, kind)
        assert isinstance(value["ref"]["$link"], str) and isinstance(value["mimeType"], str), path
        assert 0 <= value["size"] <= schema.get("maxSize", 2**63), path
    elif kind == "bytes":
        assert isinstance(value, dict) and set(value) == {"$bytes"}, (path, kind)
        base64.b64decode(value["$bytes"], validate=True)
    elif kind == "cid-link":
        assert isinstance(value, dict) and isinstance(value.get("$link"), str), (path, kind)
    else:
        raise AssertionError((path, "unsupported schema sanity-check type", kind))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    binary_fixture, binary_raw = base64_records()
    specs = [
        ("small-profile", "A", "profile", "AppBskyActorGetProfile.Output", actor(7, detailed=True), "One detailed profile with URLs, semantic identifiers, dates, viewer state and a pinned post."),
        ("medium-search", "B", "search", "AppBskyActorSearchActors.Output", {"cursor": "synthetic-search-page-2", "actors": [dict(actor(i, i % 3 == 0), description=f"Synthetic actor {i}: nature, science, software.", indexedAt=date(i + 1)) for i in range(50)]}, "50 actor-search results with Unicode in one third of profiles."),
        ("large-feed", "C", "timeline", "AppBskyFeedGetTimeline.Output", timeline(100), "100 feed entries: images, link cards, quotes, quotes with images, facets, replies, reposts, labels, viewer state."),
        ("very-large-feed", "D", "timeline", "AppBskyFeedGetTimeline.Output", timeline(800), "Expanded timeline with 800 varied entries. Stress workload larger than a normal endpoint page."),
        ("unicode-feed", "E", "timeline", "AppBskyFeedGetTimeline.Output", timeline(100, unicode=True), "100 feed entries with CJK, Arabic, Hebrew, Hangul, emoji, ZWJ, modifiers, decomposed accents, URLs, and valid UTF-8 facet offsets."),
        ("base64-records", "F", "records", "ComAtprotoRepoListRecords.Output", binary_fixture, "32 synthetic extension records containing exact IPLD $bytes objects (32 KiB each); real Petrel bytes path, not typical feed image transport."),
        ("difficult-feed", "G", "timeline", "AppBskyFeedGetTimeline.Output", timeline(100, unicode=True, difficult=True), "Nested dynamic dictionaries and arrays, known/unknown records, unknown union variants, explicit nulls, and optional/absent fields."),
        ("fidelity-edge-feed", "H", "timeline", "AppBskyFeedGetTimeline.Output", fidelity_edge_timeline(72), "72 feed entries whose link facets and link cards carry valid-but-unusual URIs (port, userinfo, empty port, IPv6, non-ASCII/IDN/emoji, %2F, %26, lowercase escapes, mailto, uppercase) plus legacy {cid,mimeType} image blobs; whitespace-padded URIs stay demoted by design."),
    ]
    fixtures = []
    for name, category, kind, swift_type, value, description in specs:
        check_facets(value)
        endpoint = {"profile": "app.bsky.actor.getProfile", "search": "app.bsky.actor.searchActors",
                    "timeline": "app.bsky.feed.getTimeline", "records": "com.atproto.repo.listRecords"}[kind]
        check_schema(value, lexicon(endpoint)["defs"]["main"]["output"]["schema"], endpoint)
        data = encoded(value)
        assert json.loads(data) == value
        (OUT / f"{name}.json").write_bytes(data)
        fixtures.append({"id": name, "file": f"{name}.json", "category": category,
                         "modelKind": kind, "swiftType": swift_type, "bytes": len(data),
                         "sha256": hashlib.sha256(data).hexdigest(), "jsonValueNodes": count_nodes(value),
                         "description": description, "provenance": "synthetic; generated from checked-in Petrel lexicon/model shapes"})
        if kind == "timeline":
            feed = value["feed"]
            fixtures[-1]["expectedTopLevelCounts"] = {
                "feed": len(feed), "postsWithEmbed": sum("embed" in item["post"] for item in feed),
                "feedItemsWithReply": sum("reply" in item for item in feed),
                "feedItemsWithReason": sum("reason" in item for item in feed),
                "knownPostRecords": sum(item["post"]["record"]["$type"] == "app.bsky.feed.post" for item in feed),
                "unknownPostRecords": sum(item["post"]["record"]["$type"] != "app.bsky.feed.post" for item in feed)}
            if name == "fidelity-edge-feed":
                # Expected under wire-preserving URI and lossless legacy-blob decoding: only records
                # carrying a whitespace-padded URI are demoted (decoding trims, re-encode differs).
                padded = sum(record_has_padded_uri(item["post"]["record"]) for item in feed)
                fixtures[-1]["validator"] = "fidelity-edge"
                fixtures[-1]["expectedTopLevelCounts"]["knownPostRecords"] -= padded
                fixtures[-1]["expectedTopLevelCounts"]["unknownPostRecords"] += padded
        elif kind == "records":
            fixtures[-1]["expectedTopLevelCounts"] = {"records": 32, "decodedPayloadBytes": 32 * len(binary_raw)}
        elif kind == "search":
            fixtures[-1]["expectedTopLevelCounts"] = {"actors": len(value["actors"])}
    (OUT / "base64-payload.bin").write_bytes(binary_raw)
    (OUT / "base64-payload.txt").write_bytes(base64.b64encode(binary_raw))
    manifest = {"schemaVersion": 1, "generatorSeed": SEED,
                "serialization": "UTF-8, ensure_ascii=false, compact separators, LF terminator; no BOM",
                "fixtures": fixtures,
                "componentFixtures": [
                    {"file": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                    for name, data in [("base64-payload.bin", binary_raw), ("base64-payload.txt", base64.b64encode(binary_raw))]
                ]}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    very_large = next(item for item in fixtures if item["category"] == "D")
    assert 1_000_000 <= very_large["bytes"] <= 10_000_000
    for item in fixtures:
        print(f"{item['id']:20s} {item['bytes']:9,d} bytes  {item['sha256']}")


if __name__ == "__main__":
    main()
