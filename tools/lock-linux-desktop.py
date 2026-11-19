#!/usr/bin/env python3
"""Resolve and pin the official Alpine packages for the Episode 2 desktop."""

from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tarfile
import urllib.request


BASE = "https://dl-cdn.alpinelinux.org/alpine/v3.24"
ROOT = Path(__file__).resolve().parent
DESKTOP = (
    "xorg-server", "xf86-input-libinput", "eudev", "xkeyboard-config", "xauth",
    "font-dejavu", "openbox", "xterm", "tint2", "pcmanfm", "feh", "mousepad", "xsetroot",
    "gdk-pixbuf-loaders", "glycin-image-rs", "glycin-svg", "adwaita-icon-theme",
)


def archive_member(data, name):
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tar:
        return tar.extractfile(name).read()


def packages(index):
    for stanza in index.decode().split("\n\n"):
        row = dict(line.split(":", 1) for line in stanza.splitlines() if ":" in line)
        if "P" in row and "V" in row:
            yield row


def download(url):
    with urllib.request.urlopen(url, timeout=55) as response:
        return response.read()


def dependency_name(value):
    return re.split("[=<>~]", value, maxsplit=1)[0]


def lock(cache):
    exact, providers = {}, {}
    for repository in ("main", "community"):
        prefix = f"{BASE}/{repository}/aarch64"
        index = archive_member(download(f"{prefix}/APKINDEX.tar.gz"), "APKINDEX")
        for row in packages(index):
            row["base"] = prefix
            exact.setdefault(row["P"], row)
            for feature in row.get("p", "").split():
                providers.setdefault(dependency_name(feature), []).append(row)

    rootfs = cache / "alpine-minirootfs-3.24.4-aarch64.tar.gz"
    with tarfile.open(rootfs) as tar:
        installed = tar.extractfile("./lib/apk/db/installed")
        baseline = {entry["P"] for entry in packages(installed.read())}

    selected = {}
    pending = list(DESKTOP)
    while pending:
        dep = pending.pop()
        if dep.startswith("!"):
            continue
        name = dependency_name(dep)
        if name in exact:
            row = exact[name]
        else:
            choices = providers.get(name, [])
            if not choices:
                raise ValueError(f"No package provides {dep}")
            row = min(choices, key=lambda candidate: (
                candidate["P"] not in baseline,
                candidate["P"] not in selected,
                candidate["P"].endswith(("-dev", "-static")),
                candidate["P"],
            ))
        package = row["P"]
        if package in selected or package in baseline:
            continue
        selected[package] = row
        pending.extend(row.get("D", "").split())

    def pin(row):
        filename = f'{row["P"]}-{row["V"]}.apk'
        url = f'{row["base"]}/{filename}'
        content = download(url)
        (cache / filename).write_bytes(content)
        return {"file": filename, "base": row["base"] + "/", "sha256": hashlib.sha256(content).hexdigest()}

    with ThreadPoolExecutor(max_workers=8) as workers:
        result = list(workers.map(pin, sorted(selected.values(), key=lambda row: row["P"])))
    (ROOT / "linux-desktop.lock.json").write_text(json.dumps(result, separators=(",", ":"), indent=2) + "\n")
    print(f"{len(result)} Alpine desktop packages pinned")


if __name__ == "__main__":
    lock(Path(sys.argv[1]))
