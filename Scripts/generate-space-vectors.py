#!/usr/bin/env python3
"""Independent Nov-12 STAR fixture (Python 3.12, cbor2 5.6.5, blake3 1.0.8).

Wire definition: bluesky-social/atproto d4def6e9f521896ed8222f576d54923d00b5fbeb
packages/space and packages/star. This does not call Petrel.
Install the two optional development-only modules in an isolated virtualenv.
"""
import base64
import hashlib
import json
import blake3
import cbor2


def cid(data):
    raw = b'\x01\x71\x12\x20' + hashlib.sha256(data).digest()
    return raw, 'b' + base64.b32encode(raw).decode().lower().rstrip('=')


def frame(data):
    number, prefix = len(data), bytearray()
    while number >= 128:
        prefix.append((number & 127) | 128)
        number >>= 7
    prefix.append(number)
    return prefix + data


space = 'at://did:example:space/space/app.bsky.group/test'
repo = 'did:example:alice'
rev = '3kbcq3p7ad422'
link, _ = cid(cbor2.dumps({'text': 'hello'}, canonical=True))
record = cbor2.dumps({'text': 'hello', 'count': 1, 'ref': cbor2.CBORTag(42, b'\0' + link)}, canonical=True)
_, record_cid = cid(record)
path = 'app.bsky.feed.post/self'
state = blake3.blake3((path + '/' + record_cid).encode()).digest(length=2048)
digest = hashlib.sha256(state).digest()
metadata = cbor2.dumps({'$type': 'atproto-space-repo', 'ver': 1, 'repo': repo, 'space': space, 'rev': rev, 'data': digest}, canonical=True)
archive = b'\x2a\x6c\x01\x00' + frame(metadata) + b'\x01' + frame(path.encode()) + frame(record) + b'\x00'
print(json.dumps({'archive': base64.b64encode(archive).decode(), 'digest': digest.hex(), 'cid': record_cid}, sort_keys=True, indent=2))
