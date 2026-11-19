#!/bin/sh
set -eu
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ -S /tmp/.X11-unix/X0 ] && [ -s /run/staffel-desktop.pid ] &&
   kill -0 "$(cat /run/staffel-desktop.pid)" 2>/dev/null; then
    exit 0
fi

chmod 1777 /tmp
for module in evdev virtio-gpu xhci-pci usbhid hid-generic; do
    modprobe "$module" || true
done
if [ ! -e /dev/dri/card0 ]; then
    echo "Virtio-Grafik fehlt" >&2
    exit 1
fi
udevd --daemon
udevadm trigger
udevadm settle --timeout=4 || true
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
update-mime-database /usr/share/mime >/tmp/staffel-mime.log 2>&1
gdk-pixbuf-query-loaders --update-cache
glib-compile-schemas /usr/share/glib-2.0/schemas
mkdir -p /usr/share/applications /etc/xdg
cp /staffel-desktop/feh.desktop /usr/share/applications/staffel-feh.desktop
printf '[Default Applications]\nimage/png=staffel-feh.desktop;\n' > /etc/xdg/mimeapps.list
rm -f /tmp/.X11-unix/X0 /tmp/.X0-lock
Xorg :0 vt1 -novtswitch -nolisten tcp -noreset -ac -extension GLX -config /staffel-desktop/xorg.conf \
    </dev/null >/tmp/staffel-xorg.log 2>&1 &
echo "$!" > /run/staffel-desktop.pid
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if DISPLAY=:0 xsetroot -solid '#182733' 2>/dev/null; then
        install -d -m 0700 -o azubi -g azubi /tmp/ostwind-azubi
        session=/staffel-desktop/session.sh
        if [ "${1:-terminal}" = terminal ]; then
            session="$session terminal"
        fi
        su -s /bin/sh azubi -c "$session" \
            </dev/null >/tmp/staffel-session.log 2>&1 &
        exit 0
    fi
    sleep 0.25
done
tail -30 /tmp/staffel-xorg.log >&2
exit 1
