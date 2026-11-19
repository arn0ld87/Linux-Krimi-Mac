#!/usr/bin/env bash
# Erzeugt die Bild-Assets für die README (docs/readme/).
#
# Quelle sind die nativen Verifikations-Screenshots aus docs/verification/.
# Die Bilder werden auf das tatsächliche App-Fenster zugeschnitten (der schwarze
# Rand des Snapshot-Modus fliegt raus), bekommen runde Ecken mit Alpha und
# werden auf Web-Größe heruntergerechnet. Daraus entsteht das Banner.
#
# Voraussetzungen: ImageMagick 7 (magick), sips (macOS).
# Nutzung: ./tools/make-readme-assets.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/docs/verification"
OUT="$ROOT/docs/readme"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"

FONT_SANS="/System/Library/Fonts/Avenir Next.ttc"
FONT_MONO="/System/Library/Fonts/Menlo.ttc"

# --------------------------------------------------------------- App-Icon
sips -s format png --resampleWidth 512 "$ROOT/Resources/AppIcon.icns" \
  --out "$TMP/icon.png" >/dev/null
magick "$TMP/icon.png" -resize 512x512 -strip "$OUT/app-icon.png"

# ------------------------------------------------------ Fenster zuschneiden
# trim entfernt den schwarzen Rand, den der Snapshot-Modus um das Fenster legt.
# Danach setzt eine runde Ecke (Radius 34) die Alpha-Maske.
window() {
  local src="$1" dst="$2" width="$3"
  magick "$SRC/$src" -fuzz 4% -trim +repage "$TMP/$dst.trim"
  local w h
  w="$(magick identify -format '%w' "$TMP/$dst.trim")"
  h="$(magick identify -format '%h' "$TMP/$dst.trim")"
  magick "$TMP/$dst.trim" \
    \( -clone 0 -alpha extract -fill white -stroke none \
       -draw "roundrectangle 0,0,$((w-1)),$((h-1)),34,34" \) \
    -alpha off -compose CopyOpacity -composite \
    -resize "${width}x" -strip "$TMP/$dst"
}

shadowed() {
  local src="$1" dst="$2" width="$3"
  magick "$src" \
    \( +clone -background '#000000' -shadow "60x40+0+18" \) \
    +swap -background none -layers merge +repage \
    -resize "${width}x" -strip "$OUT/$dst"
}

# ---------------------------------------------------------- Galerie-Bilder
# Hinweis: 08-vorwurf-erfolg.png und 11-dunkel.png sind byte-identisch –
# das Dunkelmodus-Bild ist der gelöste Vorwurf. Deshalb nur ein Bild davon.
window 01-einsatzrahmen.png      win-einsatzrahmen.png 1400
window 03-terminal-probelauf.png win-terminal.png      1400
window 04-aktenwand.png          win-aktenwand.png      1400
window 08-vorwurf-erfolg.png     win-vorwurf.png        1400
window 13-trailer.png            win-trailer.png        1400
window 10-hell.png               win-hell.png           1400

shadowed "$TMP/win-einsatzrahmen.png" einsatzrahmen.png 1200
shadowed "$TMP/win-terminal.png"      terminal.png      1200
shadowed "$TMP/win-aktenwand.png"     aktenwand.png     1200
shadowed "$TMP/win-vorwurf.png"        vorwurf.png       1200
shadowed "$TMP/win-trailer.png"        trailer.png       1200
shadowed "$TMP/win-hell.png"           hell.png          1200

# ------------------------------------------------------------- Banner
# Fast schwarzer Verlauf, Kupfer-Glow, App-Icon, Titel – rechts das
# Terminal-Fenster der App.
magick -size 2000x860 gradient:'#0b0c0a-#171913' "$TMP/bg1.png"
magick \( -size 2000x860 radial-gradient:'#6b3a1c-#0b0c0a' \) \
  \( +clone -fill black -colorize 100 \) -compose multiply -composite "$TMP/glow.png"
magick "$TMP/bg1.png" "$TMP/glow.png" -compose screen -define compose:args=45 -composite \
  -seed 42 -attenuate 0.16 +noise Gaussian -colorspace sRGB "$TMP/bg.png"

magick "$TMP/bg.png" \
  -font "$FONT_MONO" -pointsize 34 -fill 'rgba(217,112,56,0.10)' \
  -annotate +70+772 'azubi@rw-srv01:~$ ls -l /srv/rechenwerk/uebung/' \
  -annotate +70+820 'azubi@rw-srv01:~$ grep 2026-04-15 kaffeekasse.csv' \
  \( "$TMP/icon.png" -resize 200x200 \) -geometry +110+110 -composite \
  -font "$FONT_SANS" -pointsize 116 -stroke '#ecebe3' -strokewidth 2.2 \
  -fill '#ecebe3' -annotate +110+470 'NACHTDIFF' \
  -stroke none -pointsize 36 -fill '#a9ae9f' \
  -annotate +112+536 'Ein Linux-Krimi, der im echten Terminal läuft.' \
  -font "$FONT_MONO" -pointsize 26 -fill '#d97038' \
  -annotate +112+624 'swift  ·  swiftui  ·  alpine-linux-vm  ·  offline' \
  \( "$TMP/win-terminal.png" -resize 870x \) -geometry +1075+95 -composite \
  -strip -quality 90 "$OUT/banner.jpg"

echo "README-Assets geschrieben nach $OUT"
ls -la "$OUT"
