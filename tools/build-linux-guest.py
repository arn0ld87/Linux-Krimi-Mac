#!/usr/bin/env python3
"""Build the offline ARM64 Alpine guest from pinned upstream archives."""

import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request


VERSION = "3.24.4"
BASE = "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/"
PACKAGE_BASE = "https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64/"
COMMUNITY_BASE = PACKAGE_BASE.replace("/main/", "/community/")
ARCHIVES = {
    f"alpine-virt-{VERSION}-aarch64.iso":
        "cf88d8ba67389d20d9ed307366b52e487c15d7d3ee3233b62b95f709daa1d430",
    f"alpine-minirootfs-{VERSION}-aarch64.tar.gz":
        "4b14c18f7e90a063b61462ea1462a5732c154bf6adad594974fe6487cd98a8de",
}
TOOLS = {
    "coreutils-9.11-r0.apk": "956fa3cb70fbf556a3e11d3cc630e655e8d8ec855b12568302f9910f4deaf812",
    "acl-libs-2.3.2-r1.apk": "5bfce1fc46a3625268a7a60c10b5680aa846534d98856a108e692824a1f1b710",
    "libattr-2.5.2-r2.apk": "81d6c5b5eca04c2a1499407b4fbaf94bfb2ddb6c535ff4260dee862cf9803b2a",
    "utmps-libs-0.1.3.3-r0.apk": "d6487b6f260728969191314f6706d4cc62527370e757ec3ac6f7fee8ed38cf88",
    "skalibs-libs-2.15.0.0-r0.apk": "7ea58fb512067402b519079fcce8a48381eb2b9c690341c4a017aa15f719c198",
    "bash-5.3.9-r1.apk": "95f4f976bdf2f4ca18ff41c32916eb6d7b12a0dae12504d55d04427460d6542f",
    "readline-8.3.3-r1.apk": "9f0ae0923c02b0d6aba62e9173542b65396ba3f0efefcbf087ea32f1120e7b34",
    "libncursesw-6.6_p20260516-r0.apk": "51a7aa4b3ec40b144d0801c0544e0a9f62e2a41d04b6067bb5e95786040741c6",
    "diffutils-3.12-r0.apk": "579e30e49f3c02d2b8433246d838b51dfb907f4a3e455b0a61bcfbf16604bebf",
    "sudo-1.9.17_p2-r2.apk": "3d446854025ba88077b857e924f0dbbf38b849372b86fc2d0860310aa199a155",
}
HERE = Path(__file__).resolve().parent


def archive(cache, name, base, sha256):
    path = cache / name
    if path.is_file():
        with path.open("rb") as stream:
            if hashlib.file_digest(stream, "sha256").hexdigest() == sha256:
                return path
    with tempfile.NamedTemporaryFile(dir=cache, delete=False) as output:
        temporary = Path(output.name)
        try:
            with urllib.request.urlopen(base + name, timeout=90) as response:
                shutil.copyfileobj(response, output)
            output.flush()
            with temporary.open("rb") as stream:
                if hashlib.file_digest(stream, "sha256").hexdigest() != sha256:
                    raise ValueError(f"Unexpected SHA-256 for {name}")
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
    return path


def iso_file(iso, name):
    return subprocess.check_output(["tar", "-xOf", iso, name])


def build(output, cache):
    cache.mkdir(parents=True, exist_ok=True)
    iso, root_archive = (archive(cache, name, BASE, digest) for name, digest in ARCHIVES.items())
    with tempfile.TemporaryDirectory(dir=cache) as staging:
        staging = Path(staging)
        root = staging / "root"
        root.mkdir()
        subprocess.run(["tar", "-xf", root_archive, "-C", root], check=True)

        vendor_initrd = iso_file(iso, "boot/initramfs-virt")
        modules_root = staging / "modules"
        modules_root.mkdir()
        subprocess.run(["tar", "-xf", "-", "-C", modules_root, "usr/lib/modules"],
                       input=vendor_initrd, check=True)
        shutil.copytree(modules_root / "usr/lib/modules", root / "lib/modules")
        # The vendor initramfs covers early boot. Its companion modloop also
        # provides evdev and the remaining modules required by the X11 desktop.
        modloop = staging / "modloop.squashfs"
        modloop.write_bytes(iso_file(iso, "boot/modloop-virt"))
        desktop_modules = staging / "desktop-modules"
        subprocess.run(["7zz", "x", "-y", f"-o{desktop_modules}", modloop],
                       stdout=subprocess.DEVNULL, check=True)
        complete_modules = next(desktop_modules.rglob("modules.dep")).parent
        shutil.copytree(complete_modules, root / "lib/modules" / complete_modules.name,
                        dirs_exist_ok=True, symlinks=True, ignore=shutil.ignore_patterns("vmlinuz"))

        entries = subprocess.check_output(["tar", "-tf", iso], text=True).splitlines()
        packages = ("e2fsprogs", "e2fsprogs-libs", "libblkid", "libcom_err", "libeconf", "libuuid", "zlib")
        for package in packages:
            pattern = rf"apks/aarch64/{re.escape(package)}-[0-9][^/]*\.apk"
            entry, = (name for name in entries if re.fullmatch(pattern, name))
            subprocess.run(["tar", "-xf", "-", "-C", root,
                            "--exclude=.SIGN.*", "--exclude=.PKGINFO"],
                           input=iso_file(iso, entry), check=True)
        for name, digest in TOOLS.items():
            source = COMMUNITY_BASE if name.startswith("sudo-") else PACKAGE_BASE
            package = archive(cache, name, source, digest)
            subprocess.run(["tar", "-xf", package, "-C", root,
                            "--exclude=.SIGN.*", "--exclude=.PKGINFO"], check=True)
        desktop_lock = json.loads((HERE / "linux-desktop.lock.json").read_text())
        for entry in desktop_lock:
            package = archive(cache, entry["file"], entry["base"], entry["sha256"])
            subprocess.run(["tar", "-xf", package, "-C", root, "--exclude=.SIGN.*",
                            "--exclude=.PKGINFO", "--exclude=.post-*", "--exclude=.pre-*",
                            "--exclude=.trigger"], check=True)
        (root / "usr/bin/sudo").chmod(0o4755)
        missions = root / "staffel-missions"
        missions.mkdir(mode=0o700)
        shutil.copyfile(HERE.parent / "Sources/StaffelCore/Resources/Missions.json", missions / "Missions.json")
        shutil.copyfile(HERE.parent / "Resources/Einsatzszene/wiederganger-zettel.png", missions / "note.png")
        shutil.copyfile(HERE / "linux-guest/freigabe.png", missions / "freigabe.png")
        shutil.copytree(HERE / "linux-guest/desktop", root / "staffel-desktop")
        (root / "staffel-desktop/start.sh").chmod(0o755)
        (root / "staffel-desktop/session.sh").chmod(0o755)

        shutil.copyfile(HERE / "linux-guest/init.sh", root / "init")
        (root / "init").chmod(0o755)
        shutil.copyfile(HERE / "linux-guest/terminal.bashrc", root / "staffel-terminal.bashrc")
        subprocess.run(["go", "build", "-trimpath", "-ldflags=-s -w -buildid=",
                        "-o", root / "staffel-agent", HERE / "linux-guest/main.go",
                        HERE / "linux-guest/missions.go", HERE / "linux-guest/terminal.go"],
                       env={**os.environ, "GOOS": "linux", "GOARCH": "arm64", "CGO_ENABLED": "0"},
                       check=True)

        # Alpine's ARM64 EFI zboot file wraps a gzip-compressed Linux Image.
        zboot = iso_file(iso, "boot/vmlinuz-virt")
        if zboot[4:8] != b"zimg" or zboot[24:28] != b"gzip":
            raise ValueError("Unexpected Alpine EFI kernel format")
        offset, length = struct.unpack_from("<II", zboot, 8)
        kernel = gzip.decompress(zboot[offset:offset + length])
        if kernel[56:60] != b"ARM\x64":
            raise ValueError("Expected an uncompressed ARM64 Linux Image")

        (staging / "Image").write_bytes(kernel)
        subprocess.run(["tar", "--format=newc", "--uid=0", "--gid=0", "-czf",
                        staging / "initramfs.cpio.gz", "-C", root, "."], check=True)
        output.mkdir(parents=True, exist_ok=True)
        for name in ("Image", "initramfs.cpio.gz"):
            os.replace(staging / name, output / name)


if __name__ == "__main__":
    build(Path(sys.argv[1]), Path(sys.argv[2]))
