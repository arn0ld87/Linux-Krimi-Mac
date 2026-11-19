#!/bin/zsh
set -euo pipefail
repo=${0:A:h:h}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

xcrun actool "$repo/Icon/AppIcon.icon" --compile "$work" --platform macosx \
  --minimum-deployment-target 15.0 --app-icon AppIcon \
  --output-partial-info-plist "$work/partial.plist" --errors --warnings
[[ -s "$work/Assets.car" && -s "$work/AppIcon.icns" ]]
cp "$work/Assets.car" "$work/AppIcon.icns" "$repo/Resources/"
