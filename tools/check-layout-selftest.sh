#!/bin/zsh
# Negative and positive CLI regressions for tools/check-layout.swift.
# Every case must end in the documented exit code. A failed check is a
# failure of this script, not of the tool.
#
# Usage: tools/check-layout-selftest.sh
set -u
script_dir=${0:A:h}
tool="$script_dir/check-layout.swift"
work=$(mktemp -d "${TMPDIR:-/tmp}/check-layout-selftest.XXXXXX")
trap 'rm -rf "$work"' EXIT

failed=0
count=0

expect() {
  # expect <expected-exit> <label> -- <command...>
  local expected=$1 label=$2; shift 3
  count=$((count + 1))
  local output code
  output=$("$@" 2>&1)
  code=$?
  if [[ "$expected" == "nonzero" ]]; then
    if [[ $code -ne 0 ]]; then
      print "PASS $label: exit $code"
    else
      print "FAIL $label: exit 0, expected a failure"
      failed=$((failed + 1))
    fi
  else
    if [[ $code -eq $expected ]]; then
      print "PASS $label: exit $code"
    else
      print "FAIL $label: exit $code, expected $expected"
      print "  $output"
      failed=$((failed + 1))
    fi
  fi
}

run_tool() {
  swift "$tool" "$@"
}

# --- Fixtures -------------------------------------------------------------
print '{"probes":[]}' > "$work/empty.json"
print '{"probes": [' > "$work/broken.json"
print '{"window":{"width":1240,"height":820},"probes":[
  {"kind":"area","name":"page","area":"page","inset":20,"x":0,"y":0,"width":1240,"height":820},
  {"kind":"probe","name":"card","area":"page","edge":"lead","inset":0,"x":20,"y":20,"width":400,"height":100}
]}' > "$work/valid.json"
print '{"window":{"width":1240,"height":820},"probes":[
  {"kind":"area","name":"page","area":"page","inset":20,"x":0,"y":0,"width":1240,"height":820},
  {"kind":"probe","name":"card","area":"page","edge":"lead","inset":0,"x":21,"y":20,"width":400,"height":100}
]}' > "$work/violation.json"
print '{"window":{"width":1240,"height":820},"probes":[
  {"kind":"area","name":"page","area":"page","inset":20,"x":0,"y":0,"width":0,"height":820},
  {"kind":"probe","name":"card","area":"page","edge":"lead","inset":0,"x":20,"y":20,"width":400,"height":100}
]}' > "$work/bad-area.json"
mkdir -p "$work/matrix"
print '{"window":{"width":1240,"height":820},"probes":[
  {"kind":"area","name":"page","area":"page","inset":20,"x":0,"y":0,"width":1240,"height":820},
  {"kind":"probe","name":"card","area":"page","edge":"lead","inset":0,"x":20,"y":20,"width":400,"height":100}
]}' > "$work/matrix/briefing-light-layout.json"

# --- Cases ----------------------------------------------------------------
expect nonzero "no arguments"        -- run_tool
expect nonzero "empty probes"        -- run_tool "$work/empty.json"
expect nonzero "broken json"         -- run_tool "$work/broken.json"
expect nonzero "missing file"        -- run_tool "$work/does-not-exist.json"
expect nonzero "real violation"      -- run_tool "$work/violation.json"
expect nonzero "invalid area size"   -- run_tool "$work/bad-area.json"
expect nonzero "unknown option"      -- run_tool --nonsense "$work/valid.json"
expect 0       "valid fixture"       -- run_tool "$work/valid.json"

# The matrix check is separate and needs the whole screen set.
expect nonzero "incomplete matrix"   -- run_tool --require-matrix "$work/matrix" "$work/valid.json"
for page in terminal aktenwand vorwurf help; do
  cp "$work/valid.json" "$work/matrix/$page-light-layout.json"
  cp "$work/valid.json" "$work/matrix/$page-dark-layout.json"
done
cp "$work/valid.json" "$work/matrix/briefing-dark-layout.json"
expect 0 "complete matrix"          -- run_tool --require-matrix "$work/matrix" "$work/valid.json"
expect 0 "matrix directory alone"   -- run_tool --require-matrix "$work/matrix"
cp "$work/violation.json" "$work/matrix/briefing-light-layout.json"
expect 1 "one invalid matrix layout" -- run_tool --require-matrix "$work/matrix" "$work/valid.json"
rm "$work/matrix/briefing-light-layout.json"
ln -s briefing-dark-layout.json "$work/matrix/briefing-light-layout.json"
expect 1 "duplicate matrix layout via symlink" -- run_tool --require-matrix "$work/matrix"
rm "$work/matrix/briefing-light-layout.json"
for file in "$work"/matrix/*-layout.json "$work/matrix/briefing-light-layout.json"; do
  print '{"probes":[{}]}' > "$file"
done
expect 1 "invalid matrix with valid extra file" -- run_tool --require-matrix "$work/matrix" "$work/valid.json"

print ""
if [[ $failed -eq 0 ]]; then
  print "PASS check-layout selftest: $count cases"
  exit 0
fi
print "FAIL check-layout selftest: $failed of $count cases failed"
exit 1
