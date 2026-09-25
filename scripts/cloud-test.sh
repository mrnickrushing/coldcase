#!/usr/bin/env bash
# Run tests/cloud/init.luau inside a real Roblox VM via the Open Cloud Luau
# Execution API. This is the engine half of the suite - the part Lune cannot run
# because it has no Roblox datatypes and cannot load a server Service.
#
# Flow: build the place -> publish a NON-LIVE "Saved" version (players never see
# it) -> execute the test script against that exact version -> print pass/fail.
#
#   ROBLOX_API_KEY=... ./scripts/cloud-test.sh
#
# Exits non-zero if any test fails or the task errors, so CI can gate on it.
set -euo pipefail

UNIVERSE=10765931973
PLACE=131836757915254
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build/ColdCase.rbxlx"
TESTFILE="$ROOT/tests/cloud/init.luau"

: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
ROJO="rojo"; command -v rojo >/dev/null || ROJO="$HOME/.rokit/bin/rojo"

echo "==> building place"
"$ROJO" build "$ROOT/default.project.json" -o "$BUILD" >/dev/null

echo "==> publishing a non-live Saved version"
VER=$(curl -s -X POST \
  "https://apis.roblox.com/universes/v1/$UNIVERSE/places/$PLACE/versions?versionType=Saved" \
  -H "x-api-key: $ROBLOX_API_KEY" -H "Content-Type: application/xml" \
  --data-binary @"$BUILD" | python3 -c "import json,sys;print(json.load(sys.stdin)['versionNumber'])")
echo "    version $VER (not published to players)"

echo "==> running tests/cloud/init.luau in a Roblox VM"
# All the API back-and-forth (submit with retry, poll, fetch logs, report) lives
# in one Python block - far more robust than curl|python per step, which chokes
# on the occasional empty/throttled response.
UNIVERSE="$UNIVERSE" PLACE="$PLACE" VER="$VER" TESTFILE="$TESTFILE" \
KEY="$ROBLOX_API_KEY" python3 <<'PY'
import json, os, sys, time, urllib.request, urllib.error

UNIVERSE, PLACE, VER = os.environ["UNIVERSE"], os.environ["PLACE"], os.environ["VER"]
KEY, TESTFILE = os.environ["KEY"], os.environ["TESTFILE"]
BASE = "https://apis.roblox.com/cloud/v2"

def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"x-api-key": KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.load(e)
        except Exception:
            return e.code, {}
    except Exception:
        return 0, {}

script = open(TESTFILE).read()
url = f"{BASE}/universes/{UNIVERSE}/places/{PLACE}/versions/{VER}/luau-execution-session-tasks"

# Submit, retrying past the concurrent-session cap.
path = None
for _ in range(10):
    status, resp = call("POST", url, {"script": script})
    path = resp.get("path")
    if path:
        break
    time.sleep(3)
if not path:
    print("could not start a Luau execution task:", resp, file=sys.stderr)
    sys.exit(1)

# Poll to completion.
result = {}
for _ in range(40):
    status, result = call("GET", f"{BASE}/{path}")
    if result.get("state") in ("COMPLETE", "FAILED"):
        break
    time.sleep(2)

if result.get("state") == "FAILED":
    err = result.get("error", {})
    print("TASK FAILED:", err.get("code"), err.get("message"))
    _, logs = call("GET", f"{BASE}/{path}/logs")
    for page in logs.get("luauExecutionSessionTaskLogs", []):
        for m in page.get("messages", []):
            print("   ", m)
    sys.exit(1)

res = (result.get("output", {}) or {}).get("results", [{}])[0]
passed, failed = res.get("passed", 0), res.get("failed", 0)
for f in res.get("failures", []):
    print("FAIL ", f)
print(f"\n{passed} passed, {failed} failed  (engine suite, version {VER})")
sys.exit(1 if failed else 0)
PY
