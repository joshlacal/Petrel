import struct
def head(major, n):
    if n < 24: return bytes([major<<5 | n])
    if n < 256: return bytes([major<<5 | 24, n])
    if n < 65536: return bytes([major<<5 | 25]) + struct.pack('>H', n)
    if n < 2**32: return bytes([major<<5 | 26]) + struct.pack('>I', n)
    return bytes([major<<5 | 27]) + struct.pack('>Q', n)
def t(s): b=s.encode(); return head(3,len(b))+b
def bs(b): return head(2,len(b))+b
def m(pairs): 
    out=head(5,len(pairs))
    for k,v in pairs: out+= (t(k) if isinstance(k,str) else k) + v
    return out
def u(n): return head(0,n)
cid = bytes([0x01,0x71,0x12,0x20]) + bytes(range(32))
date = t("2026-01-01T00:00:00.000Z")
rows = [
 ("empty", b"", "empty input"),
 ("scalar_root_uint", u(5), "root is a scalar"),
 ("scalar_root_text", t("a"), "root is a text string"),
 ("root_array", bytes([0x82]) + m([]) + m([("a", b"\xf5")]), "root array of maps"),
 ("float64_value", m([("a", b"\xfb"+struct.pack('>d',1.5))]), "float value"),
 ("float16_value", m([("a", b"\xf9\x3c\x00")]), "half float value"),
 ("uint_above_int_max", m([("n", b"\x1b"+struct.pack('>Q',2**63))]), "2^63: throws in decodedFromDAGCBOR, stringified in CARRepository"),
 ("uint_max", m([("n", b"\x1b"+struct.pack('>Q',2**64-1))]), "2^64-1"),
 ("negint_below_int64_min", m([("n", b"\x3b"+struct.pack('>Q',2**64-1))]), "-2^64"),
 ("negint_int64_min", m([("n", b"\x3b"+struct.pack('>Q',2**63-1))]), "-2^63"),
 ("tag43", m([("x", b"\xd8\x2b"+bs(b"\x00"))]), "unsupported tag"),
 ("tag42_no_prefix", m([("x", b"\xd8\x2a"+bs(cid))]), "tag 42 payload without 0x00 prefix"),
 ("tag42_bad_cid", m([("x", b"\xd8\x2a"+bs(b"\x00\x01\x02\x03"))]), "tag 42 with invalid CID bytes"),
 ("tag42_text", m([("x", b"\xd8\x2a"+t("a"))]), "tag 42 wrapping text"),
 ("tag42_valid", m([("x", b"\xd8\x2a"+bs(b"\x00"+cid))]), "valid tag 42 link"),
 ("int_map_key", m([(u(1), t("a"))]), "integer map key"),
 ("link_non_string", m([("$link", u(5))]), "{$link: 5}"),
 ("link_bad_cid_short", m([("$link", t("notacid"))]), "{$link: notacid}"),
 ("link_bad_cid_base32", m([("$link", t("bafy!!!!notbase32!!!!"))]), "{$link: b... invalid base32}"),
 ("link_with_typed_value", m([("$link", m([("tag", t("x")), ("$type", t("app.bsky.richtext.facet#tag"))]))]), "{$link: {typed object}} (resolution must not change the string check)"),
 ("bytes_bad_base64", m([("$bytes", t("!!!"))]), "{$bytes: !!!}"),
 ("bytes_non_string", m([("$bytes", b"\xf5")]), "{$bytes: true}"),
 ("bytes_valid", m([("$bytes", t("AAH/"))]), "{$bytes: AAH/}"),
 ("type_typed_value", m([("a", u(1)), ("$type", m([("tag", t("x")), ("$type", t("app.bsky.richtext.facet#tag"))]))]), "{$type: {typed object}, a: 1}"),
 ("noncanonical_key_order", m([("b", u(1)), ("a", u(2))]), "{b:1,a:2} accepted by decodedFromDAGCBOR, rejected by preflight"),
 ("duplicate_keys", m([("a", u(1)), ("a", u(2))]), "{a:1,a:2} last wins in SwiftCBOR"),
 ("indefinite_map", b"\xbf"+t("a")+u(1)+b"\xff", "indefinite-length map"),
 ("indefinite_array_in_map", m([("a", b"\x9f"+u(1)+u(2)+b"\xff")]), "indefinite-length array"),
 ("indefinite_text_in_map", m([("a", b"\x7f"+t("ab")+t("cd")+b"\xff")]), "indefinite-length text"),
 ("invalid_utf8_text", m([("a", b"\x62\xc0\xaf")]), "invalid UTF-8 text value"),
 ("invalid_utf8_key", b"\xa1\x62\xc0\xaf\x01", "invalid UTF-8 map key"),
 ("undefined_value", m([("a", b"\xf7")]), "undefined"),
 ("simple_value", m([("a", b"\xf0")]), "simple(16)"),
 ("tag1_date_uint", m([("d", b"\xc1"+b"\x1a"+struct.pack('>I',1600000000))]), "tag 1 epoch date"),
 ("tag1_date_text", m([("d", b"\xc1"+t("a"))]), "tag 1 wrapping text (SwiftCBOR throws)"),
 ("reserved_info", b"\x1c", "reserved additional info"),
 ("truncated_map", b"\xa3"+t("a")+u(1), "map claims 3 pairs, has 1"),
 ("trailing_bytes", m([("a", u(1))])+b"\x00", "valid map followed by trailing bytes"),
 ("type_non_string", m([("$type", m([]))]), "{$type: {}}"),
 ("type_unregistered", m([("x", u(1)), ("$type", t("example.xa"))]), "{$type: example.xa, x: 1}"),
 ("type_registered_bad", m([("text", u(5)), ("$type", t("app.bsky.feed.post"))]), "{$type: app.bsky.feed.post, text: 5}"),
 ("post_extra_bigint", m([("text", t("x")), ("$type", t("app.bsky.feed.post")), ("future", b"\x1b"+struct.pack('>Q',2**63)), ("createdAt", date)]), "known post with an unknown field holding 2^63"),
 ("post_extra_float", m([("text", t("x")), ("$type", t("app.bsky.feed.post")), ("future", b"\xfb"+struct.pack('>d',0.5)), ("createdAt", date)]), "known post with an unknown float field"),
 ("post_noncanonical", m([("createdAt", date), ("text", t("x")), ("$type", t("app.bsky.feed.post"))]), "known post with non-canonical key order"),
 ("two_errors_float_and_tag", m([("a", b"\xfb"+struct.pack('>d',1.5)), ("b", b"\xd8\x2b"+bs(b"\x00"))]), "two bad entries: which error wins follows dictionary iteration"),
 ("deep_array_100", m([("a", b"\x81"*100 + u(1))]), "depth 101 (rejected by preflight)"),
 ("deep_map_70", m([("a", (b"\xa1"+t("k"))*70 + u(1))]), "nested maps depth 71"),
]
for name, b, note in rows:
    print(f'    add("{name}", "{b.hex()}", "{note}")')
