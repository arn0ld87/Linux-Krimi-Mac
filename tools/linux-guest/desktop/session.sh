#!/bin/sh
export DISPLAY=:0
export HOME=/home/azubi
export LANG=C.UTF-8
export LIBGL_ALWAYS_SOFTWARE=1
export XDG_RUNTIME_DIR=/tmp/ostwind-azubi
cd "$HOME" || exit 1
mkdir -p "$XDG_RUNTIME_DIR" "$HOME/.config/openbox"
chmod 700 "$XDG_RUNTIME_DIR"
if [ ! -e "$HOME/.config/openbox/menu.xml" ]; then
    cp /staffel-desktop/openbox-menu.xml "$HOME/.config/openbox/menu.xml"
fi
fc-cache >/dev/null 2>&1 &
feh --no-fehbg --bg-fill /staffel-desktop/wallpaper.png
pcmanfm --daemon-mode &
tint2 &
if [ "${1:-}" = terminal ]; then
    xterm -geometry 94x24+40+38 -fa 'DejaVu Sans Mono' -fs 11 -bg '#17231f' -fg '#ddf4e7' \
        -T 'Ostwind | azubi' &
fi
exec openbox
