#!/usr/bin/env bash
# ai-usage selftest — verifies every code path with mocked HTTP/auth.
# ponytail: no test framework — assert + die is enough for 8 paths.
#
# Strategy:
#   1. Build a temp AI_USAGE_CONFIG with fake auth files (one per provider).
#   2. Put a fake `curl` shim on PATH that returns canned JSON per URL.
#   3. Run ai-usage with various flags, assert on output.
#
# Exits 0 on all pass, 1 on first failure. Run from repo root:
#     ./test.sh

# No set -e: we want to count failures, not abort on the first.
cd "$(dirname "$0")"

PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fake auth files in temp config dir.
mkdir -p "$TMP/conf"
echo "sk-or-v1-fake-openrouter" > "$TMP/conf/openrouter"; chmod 600 "$TMP/conf/openrouter"
echo "sk-ant-fake-key"            > "$TMP/conf/anthropic";  chmod 600 "$TMP/conf/anthropic"
echo "sk-fake-openai"             > "$TMP/conf/openai";     chmod 600 "$TMP/conf/openai"
echo "ghp_fake"                   > "$TMP/conf/copilot";    chmod 600 "$TMP/conf/copilot"
# agy intentionally missing — exercises "no providers" path for that one only.

# Canned responses keyed by URL substring.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'SH'
#!/usr/bin/env bash
# Mock curl — match URL substring to a JSON fixture.
url="$*"
case "$url" in
  *openrouter.ai*) cat "$FIXDIR/openrouter.json" ;;
  *anthropic.com*) cat "$FIXDIR/anthropic.json" ;;
  *openai.com*)    cat "$FIXDIR/openai.json" ;;
  *github.com*)    cat "$FIXDIR/copilot.json" ;;
  *api.minimax.io*) cat "$FIXDIR/minimax.json" ;;
  *)               echo '{}' ;;
esac
SH
chmod +x "$TMP/bin/curl"

# Fixtures.
cat > "$TMP/openrouter.json" <<'JSON'
{"data":{"label":"sk-or-v1-127...a6a","usage_monthly":12.34,"byok_usage_monthly":5.67,"limit":50,"limit_remaining":37.66}}
JSON
cat > "$TMP/anthropic.json" <<'JSON'
{"id":"org-12345","name":"Test Org"}
JSON
cat > "$TMP/openai.json" <<'JSON'
{"total_granted":100.00,"total_used":42.50,"total_available":57.50}
JSON
cat > "$TMP/copilot.json" <<'JSON'
{"copilot_plan":"business","access_type":"github"}
JSON
cat > "$TMP/minimax.json" <<'JSON'
{"base_resp":{"status_code":0,"status_msg":"ok"},"model_remains":[{"model_name":"general","current_interval_remaining_percent":85.5,"current_weekly_remaining_percent":70.0}]}
JSON

export PATH="$TMP/bin:$PATH"
export AI_USAGE_CONFIG="$TMP/conf"
export FIXDIR="$TMP"
# ponytail: route every auth-detection path through $TMP/fakehome so the
# real ~/.local/share/opencode/auth.json doesn't leak in and break isolation.
export HOME="$TMP/fakehome"
mkdir -p "$TMP/fakehome"

# Test runner.
assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS  $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $name"
    echo "        expected to contain: $needle"
    echo "        got: $haystack"
    FAIL=$((FAIL+1))
  fi
}
assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  PASS  $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $name"
    echo "        expected NOT to contain: $needle"
    echo "        got: $haystack"
    FAIL=$((FAIL+1))
  fi
}

echo "==> ai-usage selftest"
echo

# 1. --bar shows numbers, not ? for configured providers.
out=$(./ai-usage --bar)
assert_contains "bar: openrouter number"   "OpenRouter"     "$out"
assert_contains "bar: anthropic  name"     "Claude"         "$out"
assert_contains "bar: openai     name"     "OpenAI"         "$out"
assert_contains "bar: copilot    name"     "GitHub"         "$out"
assert_not_contains "bar: no error marks"  "err"            "$out"
assert_not_contains "bar: no unknown ?"    "?"              "$out"

# 2. rich mode prints multi-line view (when piped, rich=0; assert on bar form).
out=$(./ai-usage 2>&1)
assert_contains "rich: openrouter" "OpenRouter" "$out"
assert_contains "rich: anthropic"  "Claude"     "$out"
assert_contains "rich: openai"     "OpenAI"     "$out"
assert_contains "rich: copilot"    "GitHub"     "$out"

# 3. no providers case — HOME pointed at a sandbox with no auth files,
#    so neither file-mode nor auto-detect finds anything.
empty_home="$TMP/emptyhome"
mkdir -p "$empty_home/.config/ai-usage"  # empty AI_USAGE_CONFIG subdir
out=$(HOME="$empty_home" AI_USAGE_CONFIG="$empty_home/.config/ai-usage" ./ai-usage --bar 2>&1)
assert_contains "no-keys: helpful msg" "no AI keys" "$out"

# 4. file-perm warning: drop a 644 key, expect WARN on stderr.
sandbox="$TMP/perm"
mkdir -p "$sandbox"
echo "leaky" > "$sandbox/openrouter"
chmod 644 "$sandbox/openrouter"
err=$(HOME="$sandbox" AI_USAGE_CONFIG="$sandbox" ./ai-usage --bar 2>&1 >/dev/null)
assert_contains "perms: warns on 644" "WARN" "$err"

# 4b. openrouter bar includes color codes (green when under cap).
# The fixture has limit=50 and usage_monthly=12.34 → pct≈25 → color 1;32 (green).
out=$(./ai-usage --bar 2>&1)
# ponytail: bar stores literal "\033" in $bar and prints with `printf %b`,
# so the on-the-wire bytes are real ESC. Match with actual ESC.
if [[ "$out" == *$'\033[1;32m'* ]]; then
  echo "  PASS  color: green ANSI on low utilization"
  PASS=$((PASS+1))
else
  echo "  FAIL  color: expected green ANSI on low utilization"
  echo "        got: $out"
  FAIL=$((FAIL+1))
fi

# 4c. bar ends with the gray separator "│".
if [[ "$out" == *$'\033[38;5;244m│\033[0m'* ]]; then
  echo "  PASS  color: gray separator"
  PASS=$((PASS+1))
else
  echo "  FAIL  color: expected gray separator"
  echo "        got: $out"
  FAIL=$((FAIL+1))
fi

# 5. JSON mode (parseable, dict with providers list).
out=$(./ai-usage --json 2>&1)
if echo "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert isinstance(d,dict)
assert isinstance(d.get("providers"),list)
assert len(d["providers"]) >= 1
' 2>/dev/null; then
  echo "  PASS  json: parses with providers[]"
  PASS=$((PASS+1))
else
  echo "  FAIL  json: did not parse as dict with providers[]"
  echo "        got: $out"
  FAIL=$((FAIL+1))
fi

# 6. --check exits 0 when all providers healthy.
./ai-usage --check >/dev/null 2>&1
if [ "$?" = 0 ]; then
  echo "  PASS  check: exits 0 on healthy providers"
  PASS=$((PASS+1))
else
  echo "  FAIL  check: should exit 0"
  FAIL=$((FAIL+1))
fi

# 7. --help exits 0 and mentions every documented flag.
out=$(./ai-usage --help 2>&1)
assert_contains "help: mentions --bar"   "--bar"   "$out"
assert_contains "help: mentions --json"  "--json"  "$out"
assert_contains "help: mentions --check" "--check" "$out"
assert_contains "help: mentions --version" "--version" "$out"

# 7b. --version exits 0 and prints a version string.
out=$(./ai-usage --version 2>&1)
if [[ "$out" == ai-usage* ]] && [ "${#out}" -lt 50 ]; then
  echo "  PASS  version: prints short version string"
  PASS=$((PASS+1))
else
  echo "  FAIL  version: got '$out'"
  FAIL=$((FAIL+1))
fi

# 8. live end-to-end: confirm --help exits 0.
./ai-usage --help >/dev/null 2>&1
if [ "$?" = 0 ]; then
  echo "  PASS  help: exits 0"
  PASS=$((PASS+1))
else
  echo "  FAIL  help: should exit 0"
  FAIL=$((FAIL+1))
fi

# 8b. error-path: bar shows 'unavailable' WITHOUT a '$' prefix.
# ponytail: a real bug was '$ unavailable' (the openrouter '$' unit prefix
# was applied unconditionally, even when the value was an error string).
mkdir -p "$TMP/errmsgbar"
echo "fakekey" > "$TMP/errmsgbar/openrouter"; chmod 600 "$TMP/errmsgbar/openrouter"
mkdir -p "$TMP/errmsgbar/bin"
cat > "$TMP/errmsgbar/bin/curl" <<'SH'
#!/usr/bin/env bash
echo '{"error":{"message":"rate limited"}}'
SH
chmod +x "$TMP/errmsgbar/bin/curl"
out=$(HOME="$TMP/errmsgbar" AI_USAGE_CONFIG="$TMP/errmsgbar" PATH="$TMP/errmsgbar/bin:$PATH" ./ai-usage --bar 2>&1)
visible=$(printf '%b' "$out" | sed 's/\x1b\[[0-9;]*m//g')
if [[ "$visible" == *"OpenRouter unavailable"* ]] && [[ "$visible" != *"\$ unavailable"* ]]; then
  echo "  PASS  error-path: bar shows 'unavailable' (no '\$' prefix)"
  PASS=$((PASS+1))
else
  echo "  FAIL  error-path: expected 'OpenRouter unavailable' without '\$'"
  echo "        got: $visible"
  FAIL=$((FAIL+1))
fi

# 9. error response → bar shows 'unavailable', --check exits 1.
mkdir -p "$TMP/errtest"
echo "fakekey" > "$TMP/errtest/openrouter"; chmod 600 "$TMP/errtest/openrouter"
mkdir -p "$TMP/errtest/bin"
cat > "$TMP/errtest/bin/curl" <<'SH'
#!/usr/bin/env bash
echo '{"error":{"message":"Missing Authentication header","code":401}}'
SH
chmod +x "$TMP/errtest/bin/curl"
out=$(HOME="$TMP/errtest" AI_USAGE_CONFIG="$TMP/errtest" PATH="$TMP/errtest/bin:$PATH" ./ai-usage --bar 2>&1)
assert_contains "error-path: bar shows unavailable" "unavailable" "$out"
HOME="$TMP/errtest" AI_USAGE_CONFIG="$TMP/errtest" PATH="$TMP/errtest/bin:$PATH" ./ai-usage --check >/dev/null 2>&1
if [ "$?" = 1 ]; then
  echo "  PASS  error-path: --check exits 1"
  PASS=$((PASS+1))
else
  echo "  FAIL  error-path: --check should exit 1"
  FAIL=$((FAIL+1))
fi

# 10. Claude Code OAuth → bar has per-segment ANSI color codes (green for 42.5%).
mkdir -p "$TMP/claude/.claude"
cat > "$TMP/claude/.claude/.credentials.json" <<'JSON'
{"claudeAiOauth":{"accessToken":"fake-oauth","expiresAt":9999999999999}}
JSON
chmod 600 "$TMP/claude/.claude/.credentials.json"
mkdir -p "$TMP/claude/bin"
cat > "$TMP/claude/bin/curl" <<'SH'
#!/usr/bin/env bash
echo '{"five_hour":{"utilization":42.5},"seven_day":{"utilization":18.0}}'
SH
chmod +x "$TMP/claude/bin/curl"
out=$(HOME="$TMP/claude" AI_USAGE_CONFIG="$TMP/claude/config" PATH="$TMP/claude/bin:$PATH" ./ai-usage --bar 2>&1)
if [[ "$out" == *"Claude"*$'\033[1;32m'*"42.5%"* ]]; then
  echo "  PASS  oauth(claude): per-segment green color"
  PASS=$((PASS+1))
else
  echo "  FAIL  oauth(claude): expected green color"
  echo "        got: $out"
  FAIL=$((FAIL+1))
fi

# 11. malformed manual key (whitespace) → warns on stderr, bar shows no provider.
mkdir -p "$TMP/badkey"
printf 'this is not a key, it has spaces\n' > "$TMP/badkey/openrouter"
chmod 600 "$TMP/badkey/openrouter"
err=$(HOME="$TMP/badkey" AI_USAGE_CONFIG="$TMP/badkey" ./ai-usage --bar 2>&1 1>/dev/null)
if [[ "$err" == *"whitespace"* ]]; then
  echo "  PASS  malformed-key: warns on whitespace"
  PASS=$((PASS+1))
else
  echo "  FAIL  malformed-key: expected whitespace warning"
  echo "        got: $err"
  FAIL=$((FAIL+1))
fi

# 12. manual key file containing JSON → extracts 'key' field, not raw blob.
mkdir -p "$TMP/jsonkey"
cat > "$TMP/jsonkey/openrouter" <<'JSON'
{"key":"sk-or-extracted-from-json","label":"my key"}
JSON
chmod 600 "$TMP/jsonkey/openrouter"
mkdir -p "$TMP/jsonkey/bin"
cat > "$TMP/jsonkey/bin/curl" <<'SH'
#!/usr/bin/env bash
echo '{"data":{"usage_monthly":42.0,"limit":100}}'
SH
chmod +x "$TMP/jsonkey/bin/curl"
out=$(HOME="$TMP/jsonkey" AI_USAGE_CONFIG="$TMP/jsonkey" PATH="$TMP/jsonkey/bin:$PATH" ./ai-usage --bar 2>&1)
if [[ "$out" == *"42.00"* ]]; then
  echo "  PASS  json-key: extracts 'key' field from JSON blob"
  PASS=$((PASS+1))
else
  echo "  FAIL  json-key: expected real number"
  echo "        got: $out"
  FAIL=$((FAIL+1))
fi

# 10b. GitHub Copilot auto-detect from `hosts.json` — `github.com` is a key
# with a literal dot in its name, which the generic dot-walker can't handle.
mkdir -p "$TMP/copilot"
mkdir -p "$TMP/copilot/.config/github-copilot"
cat > "$TMP/copilot/.config/github-copilot/hosts.json" <<'JSON'
{"github.com":{"oauth_token":"gh-fake-token","user":"octocat"}}
JSON
out=$(HOME="$TMP/copilot" AI_USAGE_CONFIG="$TMP/copilot" ./ai-usage --bar 2>&1)
visible=$(printf '%b' "$out" | sed 's/\x1b\[[0-9;]*m//g')
if [[ "$visible" == *"GitHub"* ]]; then
  echo "  PASS  copilot: dotted-key ('github.com') detected"
  PASS=$((PASS+1))
else
  echo "  FAIL  copilot: expected 'GitHub' segment in bar"
  echo "        got: $visible"
  FAIL=$((FAIL+1))
fi

# 11. --no-color strips ANSI from --bar.
out=$(./ai-usage --no-color --bar 2>&1)
# ponytail: bar stores literal "\033" in $bar and prints with `printf %b`,
# so on the wire bytes are real ESC. --no-color must strip them entirely.
if [[ "$out" != *$'\033'* ]]; then
  echo "  PASS  no-color: bar has no ANSI escapes"
  PASS=$((PASS+1))
else
  echo "  FAIL  no-color: bar still contains ESC bytes"
  echo "        got: $(od -An -c <<<\"$out\" | head -1)"
  FAIL=$((FAIL+1))
fi

# 14. NO_COLOR=1 env var also strips colors.
out=$(NO_COLOR=1 ./ai-usage --bar 2>&1)
if [[ "$out" != *$'\033'* ]]; then
  echo "  PASS  NO_COLOR: env var strips colors"
  PASS=$((PASS+1))
else
  echo "  FAIL  NO_COLOR: env var did not strip colors"
  FAIL=$((FAIL+1))
fi

echo
echo "----"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" = 0 ]
