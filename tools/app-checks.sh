#!/bin/zsh
# Prueft die App-Pfade mit echten Exitcodes.
#
# Usage: tools/app-checks.sh [pfad/zum/StaffelZwei.app]
#
# Laeuft in dieser Reihenfolge:
#   1. Selbsttest ohne APP_STORE      -> muss ungleich 0 enden (Negativfall)
#   2. Snapshot ohne APP_STORE        -> muss ungleich 0 enden (Negativfall)
#   3. Selbsttest mit eigenem Store   -> Exitcode wird protokolliert
#   4. normaler Start ohne Flags      -> eigenes Fenster per PID, Screenshot
#
# Jeder Lauf bekommt ein eigenes frisches APP_STORE. Echte Nutzerdaten werden
# nicht geoeffnet. Beendet werden nur eigene Prozesse, anhand der eigenen PID.
#
# Der Exitcode dieses Skripts ist 0, wenn alle Erwartungen gehalten wurden.
set -uo pipefail

here=${0:A:h}
repo=${here:h}
app="${1:-$repo/dist/StaffelZwei.app}"
binary="$app/Contents/MacOS/StaffelZwei"
work="$repo/.worker/app-checks"
mkdir -p "$work"
log="$work/checks.log"

if [[ ! -x "$binary" ]]; then
  print "FAIL app-checks: no binary at $binary (build first)"
  exit 1
fi

failed=0
count=0
# Kurze Watchdog-Grenzen: die Checks sollen nicht minutenlang haengen.
selftest_timeout="${APP_SELFTEST_TIMEOUT:-15}"
snapshot_timeout="${APP_SNAPSHOT_TIMEOUT:-15}"

# Ist der Bildschirm gesperrt, kann keine App ein Fenster bekommen. Das ist
# keine Eigenschaft des Programms, sondern der Session.
if python3 - <<'PY' 2>/dev/null
import subprocess, plistlib
d = plistlib.loads(subprocess.run(["ioreg", "-n", "Root", "-d", "1", "-a"], capture_output=True).stdout)
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "IOConsoleUsers":
                for u in v:
                    if isinstance(u, dict) and u.get("CGSSessionScreenIsLocked"):
                        raise SystemExit(1)
            else:
                walk(v)
    elif isinstance(o, list):
        for i in o:
            walk(i)
walk(d)
raise SystemExit(0)
PY
then
  print "NOTE: der Bildschirm ist gesperrt (CGSSessionScreenIsLocked)."
  print "      Keine App kann ein Fenster bekommen. Fenster-Pfade schlagen deshalb fehl."
fi

report() {
  # report <erwartet> <label> <exitcode>
  local expected=$1 label=$2 code=$3
  count=$((count + 1))
  if [[ "$expected" == "nonzero" ]]; then
    if [[ $code -ne 0 ]]; then
      print "PASS $label: exit $code" | tee -a "$log"
    else
      print "FAIL $label: exit 0, expected a failure" | tee -a "$log"
      failed=$((failed + 1))
    fi
  else
    if [[ $code -eq $expected ]]; then
      print "PASS $label: exit $code" | tee -a "$log"
    else
      print "FAIL $label: exit $code, expected $expected" | tee -a "$log"
      failed=$((failed + 1))
    fi
  fi
}

# --- 1. Selbsttest ohne APP_STORE (Negativfall) ---------------------------
neg1="$work/selftest-no-store.log"
env -u APP_STORE APP_SELFTEST_TIMEOUT="$selftest_timeout" "$binary" --selftest > "$neg1" 2>&1
report nonzero "selftest without APP_STORE" $?
print "  $(head -1 "$neg1")"

# --- 2. Snapshot ohne APP_STORE (Negativfall) -----------------------------
neg2="$work/snapshot-no-store.log"
env -u APP_STORE APP_SNAPSHOT="$work/snapshot-no-store" APP_SNAPSHOT_TIMEOUT="$snapshot_timeout" "$binary" > "$neg2" 2>&1
report nonzero "snapshot without APP_STORE" $?
print "  $(head -1 "$neg2")"

# --- 3. Selbsttest mit eigenem Store --------------------------------------
store3=$(mktemp -d "${TMPDIR:-/tmp}/staffelzwei-selftest.XXXXXX")
shots3="$work/selftest-shots"
self3="$work/selftest.log"
APP_STORE="$store3" APP_SELFTEST_SHOTS="$shots3" APP_SELFTEST_RESULT="$work/selftest-result.json" \
  APP_SELFTEST_TIMEOUT="$selftest_timeout" "$binary" --selftest > "$self3" 2>&1
report 0 "selftest with own store" $?
tail -3 "$self3"

# --- 4. Normaler Start, eigenes Fenster per PID ----------------------------
store4=$(mktemp -d "${TMPDIR:-/tmp}/staffelzwei-normal.XXXXXX")
APP_STORE="$store4" "$binary" > "$work/normal-start.log" 2>&1 &
pid=$!
print ""
print "normal start: pid=$pid store=$store4"
own=""
# Das Fenster-Werkzeug einmal kompilieren, dann mehrfach benutzen.
windows_bin="$work/windows"
swiftc -o "$windows_bin" "$here/windows.swift" 2>/dev/null
for _ in {1..15}; do
  sleep 1
  own=$("$windows_bin" --pid $pid 2>/dev/null | grep -v 'layer=-1' | head -1)
  [[ -n "$own" ]] && break
done
if [[ -z "$own" ]]; then
  print "FAIL normal start: no window for own pid $pid"
  failed=$((failed + 1))
  count=$((count + 1))
else
  print "PASS normal start: $own"
  window=$(print "$own" | sed -n 's/.*window=\([0-9-]*\).*/\1/p')
  shot="$work/normal-start.png"
  /usr/sbin/screencapture -x -o -l "$window" "$shot"
  if [[ -s "$shot" ]]; then
    print "PASS normal start: screenshot $shot ($(stat -f%z "$shot") bytes)"
  else
    print "FAIL normal start: no screenshot at $shot"
    failed=$((failed + 1))
  fi
  count=$((count + 1))
fi
# Nur der eigene Prozess wird beendet.
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
print "normal start: own pid $pid terminated"

print ""
if [[ $failed -eq 0 ]]; then
  print "PASS app-checks: $count checks (log: $log)"
  exit 0
fi
print "FAIL app-checks: $failed of $count checks failed (log: $log)"
exit 1
