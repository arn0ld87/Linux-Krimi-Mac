#!/bin/zsh
# Baut NACHTDIFF nach dist/NACHTDIFF.app.
# Build-Produkte liegen in ~/Library/Developer/StaffelZwei, ausserhalb des Repos.
#
# Usage: ./build.sh              Release-Build nach dist/
#        ./build.sh --debug      Debug-Build nach dist/
#        ./build.sh --install    zusaetzlich nach ~/Applications/NACHTDIFF.app
#
# Sicherheitsregeln:
#  * Es wird ausschliesslich ad-hoc signiert (kein Zertifikat, keine private
#    Entwicklungsidentitaet).
#  * Kein --force, kein --no-verify, kein --no-gpg-sign.
#  * Vorhandene Bundles werden nicht geloescht, sondern mit Zeitstempel
#    gesichert. Das neue Bundle entsteht in einem frischen Staging-Verzeichnis.
#  * Die App wird nicht automatisch gestartet.
set -euo pipefail
here=${0:A:h}
name="StaffelZwei"
bundle_name="NACHTDIFF"
scratch="$HOME/Library/Developer/$name/build"
staging_root="$HOME/Library/Developer/$name/staging"
guest_root="$HOME/Library/Developer/$name/linux-guest"
guest_cache="$HOME/Library/Developer/$name/guest-download"
config=release
install=0

for arg in "$@"; do
  case "$arg" in
    --debug)   config=debug ;;
    --install) install=1 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done

# Das Standard-SDK der Command Line Tools (macOS 27) deklariert `@State` als
# Macro und braucht dafuer das SwiftUIMacros-Plugin aus dem vollen Xcode.
# Ohne Xcode bauen wir gegen das 26.5-SDK, das `@State` als Property Wrapper
# ausliefert. Ueberschreibbar per STAFFELZWEI_SDK.
sdk="${STAFFELZWEI_SDK:-}"
if [[ -z "$sdk" ]]; then
  for candidate in "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" \
                   "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" \
                   "$HOME/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"; do
    if [[ -d "$candidate" ]]; then sdk="$candidate"; break; fi
  done
fi
sdk_args=()
[[ -n "$sdk" ]] && sdk_args=(--sdk "$sdk")

build_log=$(mktemp)
build_ok=1
swift build -c "$config" --package-path "$here" --scratch-path "$scratch" "${sdk_args[@]}" > "$build_log" 2>&1 || build_ok=0
grep -E "error:|warning:|Build complete" "$build_log" | grep -v "^\[" | head -30 || true
rm -f "$build_log"
[[ "$build_ok" == 1 ]] || { echo "build failed"; exit 1; }

bin="$scratch/$config/$name"
[[ -x "$bin" ]] || { echo "build failed: no binary"; exit 1; }
# swift build kann Erfolg melden, obwohl eine Datei nicht kompiliert wurde.
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
if [[ -n "$stale" ]]; then
  echo "build failed: binary is older than $stale"
  swift build -c "$config" --package-path "$here" --scratch-path "$scratch" "${sdk_args[@]}" 2>&1 | grep -E "error:" | head -20
  exit 1
fi

stamp=$(date +%Y%m%d%H%M%S)
if [[ ! -s "$guest_root/Image" || ! -s "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/build-linux-guest.py" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/init.sh" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-desktop.lock.json" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/desktop/start.sh" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/desktop/session.sh" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/desktop/xorg.conf" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/desktop/feh.desktop" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/desktop/wallpaper.png" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/freigabe.png" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/desktop/openbox-menu.xml" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/Sources/StaffelCore/Resources/Missions.json" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/Resources/Einsatzszene/wiederganger-zettel.png" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/main.go" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/terminal.go" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/terminal.bashrc" -nt "$guest_root/initramfs.cpio.gz" ]] ||
   [[ "$here/tools/linux-guest/missions.go" -nt "$guest_root/initramfs.cpio.gz" ]]; then
  python3 "$here/tools/build-linux-guest.py" "$guest_root" "$guest_cache"
fi
stage="$staging_root/$stamp"
app="$stage/$bundle_name.app"
mkdir -p "$stage"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
cp "$here/Resources/Assets.car" "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
cp "$here/Resources/StaffelZwei-Trailer.mp4" "$app/Contents/Resources/"
cp -R "$here/Resources/Einsatzszene" "$app/Contents/Resources/"
cp "$here/Sources/StaffelCore/Resources/Missions.json" "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/LinuxGuest"
cp "$guest_root/Image" "$guest_root/initramfs.cpio.gz" "$app/Contents/Resources/LinuxGuest/"
sed -e "s/__BUILD__/$stamp/" "$here/Info.plist.in" > "$app/Contents/Info.plist"

xattr -cr "$app"
# Die kopierte Binaerdatei darf keine eigene Signatur tragen, sonst
# verweigert codesign das Bündel. Sie wird deshalb sauber ent-signiert –
# ohne --force und ohne Sperren zu umgehen.
if codesign -dv "$app/Contents/MacOS/$name" >/dev/null 2>&1; then
  codesign --remove-signature "$app/Contents/MacOS/$name"
fi
# Ad-hoc signieren: "-" ist der Ad-hoc-Identitaet, es wird kein Zertifikat
# und keine private Entwicklungsidentitaet verwendet.
codesign --sign - --entitlements "$here/VM.entitlements" "$app"
codesign --verify --deep --strict "$app"
echo "codesign --verify --deep --strict: ok"

# Altes Bundle nicht zerstoeren: es wird mit Zeitstempel gesichert.
target="$here/dist/$bundle_name.app"
mkdir -p "$here/dist"
if [[ -e "$target" ]]; then
  backup="$here/dist/$bundle_name.app.bak-$stamp"
  mv "$target" "$backup"
  echo "moved previous app to $backup"
fi
mv "$app" "$target"
echo "built $target"

if [[ "$install" == 1 ]]; then
  install_target="$HOME/Applications/$bundle_name.app"
  if [[ -e "$install_target" ]]; then
    install_backup="$HOME/Applications/$bundle_name.app.bak-$stamp"
    mv "$install_target" "$install_backup"
    echo "moved existing app to $install_backup"
  fi
  mkdir -p "$HOME/Applications"
  cp -R "$target" "$install_target"
  echo "installed $install_target"
fi
