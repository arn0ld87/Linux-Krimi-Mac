#!/bin/sh
set -eu
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
if [ "${1:-}" != runtime ]; then
    # Bubblewrap needs a real mount as its old root. The kernel's initramfs
    # root cannot be moved with pivot_root, even inside a mount namespace.
    mkdir -p /runtime
    mount -t tmpfs -o mode=755,size=850m tmpfs /runtime
    for item in /*; do
        [ "$item" = /runtime ] && continue
        /bin/busybox cp -a "$item" /runtime/
    done
    exec /bin/busybox switch_root /runtime /init runtime
fi
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts
mount -t devpts -o mode=620,ptmxmode=666 devpts /dev/pts
mount -t proc -o nosuid,noexec,nodev proc /proc
mount -t sysfs -o nosuid,noexec,nodev sysfs /sys
ln -s /proc/self/fd /dev/fd
ln -s /proc/self/fd/0 /dev/stdin
ln -s /proc/self/fd/1 /dev/stdout
ln -s /proc/self/fd/2 /dev/stderr
hostname rw-srv01
stty -F /dev/hvc0 raw -echo
exec /staffel-agent </dev/hvc0 >/dev/hvc0 2>/dev/hvc0
