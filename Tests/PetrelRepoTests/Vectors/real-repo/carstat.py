"""Independent CAR/MST oracle (no third-party deps). Usage: carstat.py <car>"""
import sys, hashlib, base64, json, collections
def varint(b, o):
    v = s = 0
    while True:
        x = b[o]; o += 1; v |= (x & 0x7f) << s; s += 7
        if not x & 0x80: return v, o
def cbor(b, o=0):
    ib = b[o]; mt, ai = ib >> 5, ib & 31; o += 1
    if mt == 7:
        return {20: False, 21: True, 22: None}[ai], o
    if ai < 24: n = ai
    else:
        l = {24: 1, 25: 2, 26: 4, 27: 8}[ai]; n = int.from_bytes(b[o:o+l], 'big'); o += l
    if mt == 0: return n, o
    if mt == 1: return -1 - n, o
    if mt == 2: return bytes(b[o:o+n]), o + n
    if mt == 3: return b[o:o+n].decode(), o + n
    if mt == 4:
        r = []
        for _ in range(n): v, o = cbor(b, o); r.append(v)
        return r, o
    if mt == 5:
        r = {}
        for _ in range(n):
            k, o = cbor(b, o); v, o = cbor(b, o); r[k] = v
        return r, o
    if mt == 6:
        v, o = cbor(b, o); assert n == 42 and v[0] == 0; return ('cid', v[1:]), o
def cidstr(c): return 'b' + base64.b32encode(c).decode().lower().rstrip('=')
data = open(sys.argv[1], 'rb').read()
hl, o = varint(data, 0); header, _ = cbor(data[o:o+hl]); o += hl
blocks = collections.OrderedDict(); frames = 0
while o < len(data):
    l, o = varint(data, o); cid = data[o:o+36]; body = data[o+36:o+l]; o += l; frames += 1
    assert cid[:4] == b'\x01\x71\x12\x20' and hashlib.sha256(body).digest() == cid[4:], 'bad block'
    blocks[cid] = body
root = header['roots'][0][1]; commit, _ = cbor(blocks[root])
leaves = []
def walk(c):
    node, _ = cbor(blocks[c])
    if node['l']: walk(node['l'][1])
    prev = b''
    for e in node['e']:
        key = prev[:e['p']] + e['k']; prev = key
        leaves.append((key.decode(), e['v'][1]))
        if e['t']: walk(e['t'][1])
walk(commit['data'][1])
assert [k for k, _ in leaves] == sorted(k for k, _ in leaves)
cols = collections.Counter(k.split('/')[0] for k, _ in leaves)
missing = [k for k, v in leaves if v not in blocks]
print(json.dumps({
    'did': commit['did'], 'rev': commit['rev'], 'version': commit['version'],
    'commit': cidstr(root), 'data': cidstr(commit['data'][1]),
    'prev': None if commit['prev'] is None else cidstr(commit['prev'][1]),
    'carBytes': len(data), 'carSHA256': hashlib.sha256(data).hexdigest(),
    'frames': frames, 'distinctBlocks': len(blocks), 'records': len(leaves),
    'distinctRecordCIDs': len(set(v for _, v in leaves)), 'missingRecordBlocks': len(missing),
    'collections': dict(sorted(cols.items())),
}, indent=2))
