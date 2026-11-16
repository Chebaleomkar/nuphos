#!/usr/bin/env bash
# Side-by-side timing of current vs candidate tools. Benchmark only: every command's
# exit code and output are recorded, nothing here gates anything.
set -u
OUT="$RUNNER_TEMP/bench"; mkdir -p "$OUT"
SUM="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
row() { echo "| $1 | $2 | $3 | $4 |" >> "$SUM"; }
timed() { # label dir logname cmd...
  local label=$1 dir=$2 log=$3; shift 3
  local s e rc; s=$(date +%s.%N)
  (cd "$dir" && "$@") > "$OUT/$log" 2>&1; rc=$?
  e=$(date +%s.%N)
  row "$label" "$(printf '%.1f' "$(echo "$e - $s" | bc)")s" "$rc" "$(tail -n 1 "$OUT/$log" | tr '|' '/' | cut -c1-120)"
}
echo "## $BENCH_APP on $(nproc) cores" >> "$SUM"
echo "| step | time | exit | last line |" >> "$SUM"; echo "|---|---|---|---|" >> "$SUM"
case "$BENCH_APP" in
desktop)
  D=apps/desktop
  timed "install pnpm" $D install-pnpm.log pnpm install --frozen-lockfile
  timed "eslint (current)" $D eslint.log env NODE_OPTIONS=--max-old-space-size=8192 pnpm exec eslint . -f json -o "$OUT/eslint.json"
  timed "tsc -b (current)" $D tsc.log pnpm exec tsc -b --noEmit
  timed "tsgo -b (TS 7)" $D tsgo.log npx -y -p @typescript/native-preview tsgo -b --noEmit
  timed "bun check" $D buncheck.log bun check
  timed "oxlint migrate" $D migrate.log npx -y @oxlint/migrate@latest --type-aware --js-plugins --with-nursery --details
  cp $D/.oxlintrc.json "$OUT/desktop.oxlintrc.json" 2>/dev/null
  timed "oxlint --type-aware" $D oxlint.log npx -y -p oxlint@latest -p oxlint-tsgolint@latest oxlint --type-aware -f json
  ;;
backend)
  D=apps/backend
  timed "install bun" $D install-bun.log bun install --frozen-lockfile
  timed "eslint (current)" $D eslint.log env NODE_OPTIONS=--max-old-space-size=4096 bun x eslint . -f json -o "$OUT/eslint.json"
  timed "tsc (current)" $D tsc.log env NODE_OPTIONS=--max-old-space-size=4096 bun x tsc --noEmit
  timed "tsgo (TS 7)" $D tsgo.log npx -y -p @typescript/native-preview tsgo --noEmit
  timed "bun check" $D buncheck.log bun check
  timed "oxlint migrate" $D migrate.log npx -y @oxlint/migrate@latest --type-aware --js-plugins --with-nursery --details
  cp $D/.oxlintrc.json "$OUT/backend.oxlintrc.json" 2>/dev/null
  timed "oxlint --type-aware" $D oxlint.log npx -y -p oxlint@latest -p oxlint-tsgolint@latest oxlint --type-aware -f json
  ;;
format)
  timed "install root" . install-root.log bun install --frozen-lockfile
  timed "prettier --check (current)" . prettier.log bun run format:check
  timed "oxfmt --check" . oxfmt.log npx -y oxfmt@latest --check
  ;;
esac
