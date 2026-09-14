#!/usr/bin/env python3
"""Rebuild the offline LazyVim payload from its pinned GitHub snapshots."""
import concurrent.futures
import gzip
import hashlib
import io
import json
import posixpath
from pathlib import Path, PurePosixPath
import tarfile
import urllib.request

root = Path(__file__).resolve().parent.parent
vendor = root / "vendor/nvim"
plugins = json.loads((vendor / "plugins.lock.json").read_text())


def download(item):
    name, plugin = item
    url = f"https://codeload.github.com/{plugin['repo']}/tar.gz/{plugin['commit']}"
    with urllib.request.urlopen(url, timeout=60) as response:
        return name, response.read()


with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    snapshots = dict(pool.map(download, plugins.items()))

archive = vendor / "plugins.tar.gz"
temporary = archive.with_suffix(".tmp")
try:
    with temporary.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode="w", format=tarfile.PAX_FORMAT) as output:
            for name, data in sorted(snapshots.items()):
                with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as source:
                    for member in sorted(source.getmembers(), key=lambda entry: entry.name):
                        parts = PurePosixPath(member.name).parts[1:]
                        if not parts or parts[0] in {".github", "test", "tests"}:
                            continue
                        if ".." in parts:
                            raise ValueError(f"unsafe snapshot member: {member.name}")
                        if member.issym():
                            target = posixpath.normpath(posixpath.join(posixpath.dirname(member.name), member.linkname))
                            if not target.startswith(member.name.split("/")[0] + "/"):
                                raise ValueError(f"unsafe snapshot link: {member.name}")
                            member = source.getmember(target)
                        if not (member.isfile() or member.isdir()):
                            raise ValueError(f"unsupported snapshot member: {member.name}")
                        entry = tarfile.TarInfo(str(PurePosixPath(name, *parts)))
                        entry.type = member.type
                        entry.mode = 0o755 if member.isdir() or member.mode & 0o111 else 0o644
                        entry.size = member.size
                        output.addfile(entry, source.extractfile(member) if member.isfile() else None)
    temporary.replace(archive)
finally:
    temporary.unlink(missing_ok=True)

checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(vendor / "SHA256SUMS").write_text(f"{checksum}  {archive.name}\n")
manifest_path = vendor.parent / "manifest.lock.json"
manifest = json.loads(manifest_path.read_text())
manifest["nvim_configs"]["offline_plugins"]["sha256"] = checksum
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Packaged {len(plugins)} pinned plugins: {archive}")
