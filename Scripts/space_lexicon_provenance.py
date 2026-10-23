#!/usr/bin/env python3
"""Verify or vendor the reviewed Spaces corpus without rewriting upstream bytes."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "generator/provenance/spaces.json"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_tree(root, manifest):
    actual = {
        str(path.relative_to(root)): digest(path.read_bytes())
        for namespace in manifest["namespaces"]
        for path in sorted((root / namespace).rglob("*.json"))
    }
    if actual != manifest["files"]:
        missing = sorted(manifest["files"].keys() - actual.keys())
        extra = sorted(actual.keys() - manifest["files"].keys())
        changed = sorted(path for path in actual.keys() & manifest["files"].keys()
                         if actual[path] != manifest["files"][path])
        raise ValueError(f"Spaces corpus differs: missing={missing}, extra={extra}, changed={changed}")
    pin = root / "com/atproto/space/.pin"
    if pin.read_text().strip() != manifest["commit"]:
        raise ValueError("Spaces .pin differs from reviewed provenance")


def archive_corpus(archive, manifest):
    if digest(archive.read_bytes()) != manifest["archive_sha256"]:
        raise ValueError("Upstream archive SHA-256 differs from reviewed provenance")
    prefix = f"atproto-{manifest['commit']}/lexicons/"
    corpus = {}
    with tarfile.open(archive, "r:gz") as source:
        for member in source.getmembers():
            if not member.name.startswith(prefix):
                continue
            relative = member.name[len(prefix):]
            if not any(relative.startswith(ns + "/") for ns in manifest["namespaces"]):
                continue
            if member.isdir():
                continue
            if not member.isfile() or not relative.endswith(".json") or relative in corpus:
                raise ValueError(f"Unexpected archive member: {relative}")
            corpus[relative] = source.extractfile(member).read()
    if {name: digest(data) for name, data in corpus.items()} != manifest["files"]:
        raise ValueError("Upstream archive corpus differs from reviewed file inventory")
    return corpus


def vendor(root, manifest, corpus):
    # Stage and validate before replacing either namespace. Preserve the previous
    # directories for recovery instead of deleting uncommitted user content.
    staging = Path(tempfile.mkdtemp(prefix="petrel-spaces-vendor-"))
    for name, data in corpus.items():
        target = staging / "new" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    (staging / "new/com/atproto/space/.pin").write_text(manifest["commit"] + "\n")
    verify_tree(staging / "new", manifest)
    for namespace in manifest["namespaces"]:
        target = root / namespace
        if target.exists():
            previous = staging / "previous" / namespace
            previous.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(target), str(previous))
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(staging / "new" / namespace), str(target))
    print(f"Previous schemas retained at {staging / 'previous'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["verify", "vendor"])
    parser.add_argument("--archive", type=Path, help="Compare to the pinned codeload archive")
    parser.add_argument("--lexicons", type=Path, default=ROOT / "generator/lexicons")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    archive = args.archive
    if args.action == "vendor" and archive is None:
        archive = Path(tempfile.mkdtemp(prefix="petrel-spaces-source-")) / "atproto.tar.gz"
        urllib.request.urlretrieve(manifest["archive_url"], archive)
    corpus = archive_corpus(archive, manifest) if archive else None
    if args.action == "vendor":
        vendor(args.lexicons, manifest, corpus)
    verify_tree(args.lexicons, manifest)
    print(f"Verified {len(manifest['files'])} exact Spaces schemas at {manifest['commit']}")


if __name__ == "__main__":
    main()
