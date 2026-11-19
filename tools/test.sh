#!/bin/zsh
# Reproduzierbarer Test-Entry-Point fuer die Core-Tests von StaffelZwei.
#
# Usage:
#   tools/test.sh [--sdk <pfad>] [--plugin-path <pfad>] [-- <weitere Argumente>]
#
# Was das Skript tut:
#   * findet SDK und Swift-Testing-Makro-Plugin aus der aktiven Toolchain,
#   * setzt die Flags nur, wenn sie noetig sind,
#   * benutzt ein eigenes frisches APP_STORE (echte Nutzerdaten werden nie
#     geoeffnet),
#   * gibt den Exitcode von `swift test` unveraendert zurueck,
#   * wertet einen Lauf ohne ausgefuehrte Tests als Fehler, nicht als Erfolg.
#
# Ueberschreibungen (optional):
#   STAFFELZWEI_SDK           Verzeichnis des macOS-SDK
#   STAFFELZWEI_TEST_PLUGIN   Verzeichnis mit libTestingMacros.dylib
#   STAFFELZWEI_TEST_SCRATCH  Build-Verzeichnis fuer swift test
set -uo pipefail

here=${0:A:h}
repo=${here:h}

sdk="${STAFFELZWEI_SDK:-}"
plugin="${STAFFELZWEI_TEST_PLUGIN:-}"
extra=()
while (( $# > 0 )); do
  case "$1" in
    --sdk)
      [[ $# -ge 2 ]] || { print "FAIL test: --sdk needs a path"; exit 2 }
      sdk=$2; shift 2 ;;
    --plugin-path)
      [[ $# -ge 2 ]] || { print "FAIL test: --plugin-path needs a path"; exit 2 }
      plugin=$2; shift 2 ;;
    --)
      shift; extra=("$@"); break ;;
    *)
      extra+=("$1"); shift ;;
  esac
done

swift_bin=$(command -v swift) || { print "FAIL test: no swift in PATH"; exit 1 }
toolchain=$(xcode-select -p 2>/dev/null)
[[ -n "$toolchain" && -d "$toolchain" ]] || toolchain=${swift_bin:A:h:h}

# --- SDK -------------------------------------------------------------------
# Das macOS-27-SDK der Command Line Tools deklariert `@State` als Macro und
# braucht dafuer das SwiftUIMacros-Plugin aus dem vollen Xcode. Ohne Xcode
# baut das Paket gegen das 26.5-SDK. Reihenfolge: Vorgabe, Toolchain, xcrun.
if [[ -z "$sdk" ]]; then
  for candidate in \
    "$toolchain/SDKs/MacOSX26.5.sdk" \
    "$toolchain/SDKs/MacOSX26.sdk" \
    "$toolchain/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk" \
    "$toolchain/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.sdk"; do
    [[ -d "$candidate" ]] && { sdk=$candidate; break }
  done
fi
if [[ -z "$sdk" ]]; then
  sdk=$(xcrun --show-sdk-path 2>/dev/null || true)
fi
if [[ -z "$sdk" || ! -d "$sdk" ]]; then
  print "FAIL test: no macOS SDK found (set STAFFELZWEI_SDK or pass --sdk)"
  exit 1
fi

# --- Swift-Testing-Makro-Plugin -------------------------------------------
# Das Plugin liegt in <toolchain>/usr/lib/swift/host/plugins/testing und wird
# von SwiftPM nicht selbst gesucht. Ohne --plugin-path bricht der Testlauf
# beim Kompilieren ab.
plugin_args=()
needs_plugin_path=1
if [[ -z "$plugin" ]]; then
  for dir in "$toolchain/usr/lib/swift/host/plugins" "$toolchain/usr/lib/swift/macosx/plugins"; do
    if [[ -f "$dir/libTestingMacros.dylib" ]]; then
      # Der Standardsuchpfad enthaelt das Plugin: kein Flag noetig.
      needs_plugin_path=0
      break
    fi
  done
  if (( needs_plugin_path )); then
    for candidate in \
      "$toolchain/usr/lib/swift/host/plugins/testing" \
      "$toolchain/usr/lib/swift/macosx/plugins/testing" \
      "$toolchain/usr/lib/swift/host/plugins" \
      "$toolchain/usr/lib/swift/macosx/plugins"; do
      if [[ -f "$candidate/libTestingMacros.dylib" ]]; then
        plugin=$candidate
        break
      fi
    done
  fi
fi
if (( needs_plugin_path )); then
  if [[ -z "$plugin" || ! -f "$plugin/libTestingMacros.dylib" ]]; then
    print "FAIL test: Swift Testing macro plugin not found (libTestingMacros.dylib)."
    print "      Set STAFFELZWEI_TEST_PLUGIN or pass --plugin-path."
    exit 1
  fi
  plugin_args=(-Xswiftc -plugin-path -Xswiftc "$plugin")
fi

# --- Frischer Store --------------------------------------------------------
store=$(mktemp -d "${TMPDIR:-/tmp}/staffelzwei-test-store.XXXXXX") || {
  print "FAIL test: cannot create a store directory"; exit 1 }
scratch="${STAFFELZWEI_TEST_SCRATCH:-$HOME/Library/Developer/StaffelZwei/build-tests}"

print "test: sdk=$sdk"
print "test: plugin=$plugin"
print "test: store=$store"

log="$store/swift-test.log"
APP_STORE="$store" swift test \
  --package-path "$repo" \
  --scratch-path "$scratch" \
  --sdk "$sdk" \
  "${plugin_args[@]}" \
  "${extra[@]}" > "$log" 2>&1
exit_code=$?

tail -n 25 "$log"
print ""
if [[ $exit_code -ne 0 ]]; then
  print "FAIL test: swift test exited with $exit_code (log: $log)"
  exit $exit_code
fi
# "Test run with 45 tests in 0 suites passed" - ohne Tests ist das kein Erfolg.
if ! grep -qE "Test run with [1-9][0-9]* tests?" "$log"; then
  print "FAIL test: swift test reported no executed tests (log: $log)"
  grep -E "error:|warning:" "$log" | head -10 || true
  exit 1
fi
tests=$(grep -oE "Test run with [0-9]+ tests?" "$log" | tail -1)
print "PASS test: $tests, exit 0 (log: $log)"
exit 0
