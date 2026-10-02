#!/usr/bin/env python3
"""Fetch the exact public single-header simdjson snapshot, with byte verification."""
from pathlib import Path
import hashlib, urllib.request
root=Path(__file__).resolve().parent/'Vendor/simdjson'
revision='8c512a3227ad322bfcb43c57c71fac67a83b5b8e'
files={
 'simdjson.cpp':('singleheader/simdjson.cpp','369d633ca839595cadda035feee0cf3a90614b6264ba3cdff2295ba0ce4a382a'),
 'simdjson.h':('singleheader/simdjson.h','5c736b99cae80fff22d2dc321e8d7fa6f6c15b5493f7a5d00dc2f24253206f8d'),
 'LICENSE':('LICENSE','5fa8894e890bd77958f93b165433e0fb0dffa5bc982bfb147e4748e95bad24e5')}
root.mkdir(parents=True,exist_ok=True)
for name,(remote,digest) in files.items():
 path=root/name
 data=path.read_bytes() if path.exists() else urllib.request.urlopen('https://raw.githubusercontent.com/simdjson/simdjson/'+revision+'/'+remote,timeout=60).read()
 if hashlib.sha256(data).hexdigest()!=digest:raise SystemExit('Unexpected source hash: '+name)
 if not path.exists():path.write_bytes(data)
print('simdjson 5.0.1 snapshot verified')
