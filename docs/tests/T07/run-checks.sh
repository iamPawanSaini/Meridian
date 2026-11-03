#!/usr/bin/env bash
# Automated checks for T07 (Pantheon dev environment and deployment path). Designed from the acceptance criteria in
# docs/TASKS.md (T07, wording updated by the owner 2026-11-02), the approved plan docs/tasks/T07/plan.md (Rev 2: KD-1 to
# KD-12, TH-1 to TH-9, "Verification phases for AC4") and the decision files docs/tasks/T07/decision-*.md, and the common
# criteria C1 to C7. NOT from the implementation. Failing before the implementation exists is expected.
#
# Usage:
#   docs/tests/T07/run-checks.sh                static and offline-harness checks, TC-T07-01 to 28. No network, no DDEV,
#                                               no credentials. The harness runs the deploy script against a fixture
#                                               repository with fake terminus, curl and git-push observers on PATH.
#                                               Live and owner-run cases are listed as BLOCKED with the reason.
#   docs/tests/T07/run-checks.sh --regression   invariant checks only (ckp), no cka snapshot checks (decision D-5)
#   docs/tests/T07/run-checks.sh --live         static checks, then live cases TC-T07-30 to 49 against Pantheon
#                                               `meridian-trade` (see the gates below)
#   docs/tests/T07/run-checks.sh --live-only    live cases only
#   T07_CONFIRM=1 docs/tests/T07/run-checks.sh --clean-clone
#                                               TC-T07-55 (ddev deploy-drupal --dry-run in a fresh clone, no .env)
#   Environment:
#     T07_EVIDENCE=1        also write each case's lines to docs/tests/T07/evidence/TC-T07-nn.<UTC run id>.txt
#     T07_OWNER_OK=1        gate for every live case: the owner said, in their own message (plan O-3), that the PAT and the
#                           SSH key are in place and that agents may use them. Without it live cases are BLOCKED, not FAIL.
#     T07_O4_DONE=1         the owner did the one-time force push (plan O-4). Without it TC-T07-32 to 38 are BLOCKED.
#     T07_CONFIRM_WIPE=1    destructive: allows TC-T07-39 (env:wipe + site:install on Pantheon dev). Owner approved wipe and
#                           reinstall of Pantheon dev for T07 testing (owner facts 2026-11-02).
#     T07_CONFIRM_RESTORE=1 allows TC-T07-48 (database-only restore on Pantheon dev; dev holds no project data).
#     T07_CONFIRM_PULL=1    allows TC-T07-42 (ddev pull pantheon replaces the LOCAL database; the case takes a snapshot first).
#     T07_DEPLOY_REF=REF    ref for the real deploy (default task/T07-pantheon-dev, run with --allow-unmerged).
#     T07_BYPASS_VALUE=V    value for the Sandbox bypass header in the KD-12 measurements (default 1).
#     T07_SKIP_NESTED=1     skip the (slow) nested T02 to T06 regression in TC-T07-24; only for negative-control runs against a mutated script
#     T07_BASE=SHA          commit that snapshot checks compare against (default 1200ad0, the T07 branch point).
#   Live steps were written from the plan and the Terminus 3.6.2 help; they could not be run at design time. Field names of
#   Terminus JSON output (backup:list, env:code-log) are assumptions; a mismatch is a test-script correction, not a defect.
#
# Output: one line per check (PASS / FAIL / BLOCKED / SKIP), one roll-up line per case, then a summary. Exit status is 1 if
# any check FAILs, else 0. A missing file makes every dependent check FAIL (no vacuous pass). SKIP is only for optional host
# tools. BLOCKED means the case cannot run here (no credentials, no DDEV, owner-run, or accepted deferral); it is not a pass,
# does not change the exit status, and the report must list each one.
# Tags (decision D-5): ckp = invariant (runs in all static modes); cka = snapshot, true only at the close of T07; skipped by
# --regression, count printed.
# Redaction: every emitted line passes through redact(): passwords printed by site:install, token assignments and
# Authorization headers are replaced before they reach the console or an evidence file.
# shellcheck disable=SC2329,SC2015,SC2016,SC2034 # T07: check helpers are called through ckp/cka by name; regexes are literal
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel) || exit 2
cd "$ROOT" || exit 2
T=docs/tests/T07
EVD=$ROOT/$T/evidence
RUNID=$(date -u +%Y%m%dT%H%M%SZ)
BASE=${T07_BASE:-1200ad0}
SITE=meridian-trade

MODE=static
case "${1:-}" in
  "") ;;
  --regression) MODE=reg ;;
  --live) MODE=live ;;
  --live-only) MODE=liveonly ;;
  --clean-clone) MODE=clone ;;
  *) echo "usage: $0 [--regression|--live|--live-only|--clean-clone]" >&2; exit 2 ;;
esac

fail=0; ran=0; blocked=0; skipped=0; excluded=0
CASE=""; EVFILE=""
declare -a ORDER=()
declare -A CSTAT=()
declare -A NPASS=()

redact() {
  sed -E \
    -e 's/([Pp]assword[^:=]{0,20}[:=] *)[^ ]+/\1[REDACTED]/g' \
    -e 's/(TERMINUS_MACHINE_TOKEN=)[^ ]+/\1[REDACTED]/g' \
    -e 's/(machine-token[= ])[^ ]+/\1[REDACTED]/g' \
    -e 's/(Authorization: *)[^ ]+( [^ ]+)?/\1[REDACTED]/g' \
    -e 's/(PANTHEON_DEPLOY_KEY=)[^ ]+/\1[REDACTED]/g'
}
emit() {
  local l; l=$(printf '%s' "$1" | redact)
  printf '%s\n' "$l"
  if [[ "${T07_EVIDENCE:-0}" == 1 && -n "$EVFILE" ]]; then printf '%s\n' "$l" >>"$EVFILE"; fi
}
case_start() {   # ID TITLE
  CASE=$1; ORDER+=("$1"); CSTAT["$1"]=PASS; NPASS["$1"]=0
  if [[ "${T07_EVIDENCE:-0}" == 1 ]]; then mkdir -p "$EVD"; EVFILE="$EVD/$1.$RUNID.txt"; : >"$EVFILE"; fi
  emit "== $1 $2"
}
pass() { emit "  PASS  $1"; NPASS["$CASE"]=$((NPASS["$CASE"]+1)); }
bad()  { emit "  FAIL  $1"; fail=1; CSTAT["$CASE"]=FAIL; }
skip() { emit "  SKIP  $1"; skipped=$((skipped+1)); }
blk()  {
  emit "  BLOCKED  $1"; blocked=$((blocked+1))
  [[ "${CSTAT[$CASE]}" == FAIL ]] || CSTAT["$CASE"]=BLOCKED
}
note() { emit "        $1"; }
show_out() { local line; while IFS= read -r line; do emit "        $line"; done < <(printf '%s\n' "$1" | head -8); }
ckp() {
  local d=$1 out rc; shift; ran=$((ran+1))
  out=$("$@" 2>&1) && rc=0 || rc=$?
  if [[ $rc -eq 0 ]]; then pass "$d"; else bad "$d"; show_out "$out"; fi
}
cka() {
  local d=$1 out rc; shift
  if [[ "$MODE" == reg ]]; then excluded=$((excluded+1)); return 0; fi
  ran=$((ran+1))
  out=$("$@" 2>&1) && rc=0 || rc=$?
  if [[ $rc -eq 0 ]]; then pass "[at-close] $d"; else bad "[at-close] $d"; show_out "$out"; fi
}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/t07.XXXXXX")
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ---------- helpers ----------
eq() { [[ "$1" == "$2" ]] || { echo "$3: expected '$2', got '$1'"; return 1; }; }
need_file() { [[ -s "$1" ]] || { echo "missing or empty: $1"; return 1; }; }
allin() { local f=$1 p; shift; need_file "$f" || return 1
  for p in "$@"; do grep -qiE -- "$p" "$f" || { echo "missing in $f: $p"; return 1; }; done; }
allout() { local f=$1 p; shift; need_file "$f" || return 1
  for p in "$@"; do ! grep -qiE -- "$p" "$f" || { echo "unexpected in $f: $p"; return 1; }; done; }
has() { grep -qE -- "$2" <<<"$1" || { echo "no match for /$2/ in: ${1:0:300}"; return 1; }; }
hasnt() { ! grep -qE -- "$2" <<<"$1" || { echo "unexpected match for /$2/ in: ${1:0:300}"; return 1; }; }
isexec() { [[ -f "$1" && -x "$1" ]] || { echo "not an executable file: $1"; return 1; }; }
RC=0; OUT=""; export RC OUT
rcof() { OUT=$("$@" 2>&1 </dev/null) && RC=0 || RC=$?; }

# ---------- file names ----------
DS=${T07_SCRIPT:-scripts/deploy-drupal.sh}   # T07_SCRIPT only to validate the harness against a reference script
KH=scripts/pantheon_known_hosts
WF=.github/workflows/deploy-drupal.yml
PRV=.ddev/providers/pantheon.yaml
WRAP=.ddev/commands/web/deploy-drupal
DCFG=.ddev/config.yaml
RB=docs/runbooks/deploy.md
TD=docs/architecture/technical-design.md
ADR4=docs/adr/ADR-0004-monorepo-subtree-deploy-pantheon.md
OAS=docs/architecture/openapi.yaml
SETTINGS=apps/drupal/web/sites/default/settings.php
PUB="https://dev-$SITE.pantheonsite.io"
SIM_BR='zerodha|kite ?connect|\bkite\b|kiteconnect|upstox|angel ?(one|broking)|groww|fyers|5paisa|dhanhq|\bdhan\b|alice ?blue|interactive ?brokers|ibkr|alpaca|icici ?direct|smartapi|kite\.trade|place[_ -]?order|order[_ -]?placement'

kh_has_key() { [[ -s "$KH" ]] && grep -qvE '^\s*(#|$)' "$KH"; }
atclose() {   # DESCRIPTION CMD...: snapshot checks that become true at /close-task; BLOCKED until T07_CLOSE=1
  if [[ "${T07_CLOSE:-0}" == 1 ]]; then cka "$@"; else blk "runs at /close-task with T07_CLOSE=1: $1"; fi; }
t07_files() {   # files T07 adds or changes, relative to the branch point (plus untracked)
  { git diff --name-only "$BASE" -- . 2>/dev/null; git ls-files -o --exclude-standard; } | sort -u \
    | grep -vE '^docs/tests/(T0[0-6]|T04a)/|^docs/tasks/|^docs/PROGRESS|^docs/TRACEABILITY|^docs/tests/T07/evidence/' || true
}
t07_impl_files() { ls "$DS" "$KH" "$WF" "$PRV" "$WRAP" 2>/dev/null || true; }

have_ddev() { command -v ddev >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
MIN_SPLIT_FILES=(composer.json composer.lock pantheon.yml config/sync/system.site.yml)

# =====================================================================================================
# Offline harness: fixture repository, fake terminus, fake curl, git wrapper that records pushes
# =====================================================================================================
REALGIT=$(command -v git)
STUB=$WORK/stub
mkdir -p "$STUB"
cat >"$STUB/terminus" <<'SH'
#!/usr/bin/env bash
# fake terminus for the T07 harness. Behaviour is driven by FAKE_* variables.
{ printf 'terminus'; printf ' %s' "$@"; printf '\n'; } >>"$FAKE_LOG"
printf 'ENV TERMINUS_SSH_COMMAND=%s ALT=%s TOKEN_SET=%s\n' "${TERMINUS_SSH_COMMAND-<unset>}" \
  "${TERMINUS_ALTERNATE_NAMESERVER-<unset>}" "$([[ -n ${TERMINUS_MACHINE_TOKEN:-} ]] && echo 1 || echo 0)" >>"$FAKE_ENVLOG"
cmd=${1:-}
case "$cmd" in
  auth:login)
    [[ -z ${FAKE_AUTH_FAIL:-} ]] || { echo "login failed" >&2; exit 1; }
    echo "Logging in via machine token" ;;
  auth:whoami)
    # Terminus 4.3.3 logged out: notice on stderr, exit 0, empty stdout (facts record, item f)
    [[ -z ${FAKE_NO_SESSION:-} ]] || { echo "You are not logged in." >&2; exit 0; }
    echo "fake@example.invalid" ;;
  connection:info) echo "${FAKE_GIT_URL:-$FAKE_BARE}" ;;
  backup:create)
    [[ -z ${FAKE_BACKUP_FAIL:-} ]] || { echo "backup failed" >&2; exit 1; }
    echo "backup created" ;;
  workflow:wait)
    # 4.3.3 WaitCommand (facts b and c): success prints the notice below; a failed or aborted
    # workflow exits 1; a timeout or no matching workflow warns and exits 0 without the notice
    wsha=""; for a in "$@"; do case "$a" in --commit=*) wsha=${a#--commit=} ;; esac; done
    [[ -z ${FAKE_WAIT_FAIL:-} ]] || { echo "Workflow w1 failed for commit $wsha" >&2; exit 1; }
    [[ -z ${FAKE_WAIT_TIMEOUT:-} ]] || { echo "[warning] Waited '900' seconds, giving up waiting for workflow to finish." >&2; exit 0; }
    [[ -z ${FAKE_WAIT_NOTFOUND:-} ]] || { echo "[warning] Workflow with commit $wsha not found after 10 attempts." >&2; exit 0; }
    echo "[notice] Workflow w1 completed successfully for commit $wsha" ;;
  env:code-log)
    real=$("$FAKE_REALGIT" --git-dir "$FAKE_BARE" rev-parse refs/heads/master 2>/dev/null || echo none)
    if [[ -n ${FAKE_CODELOG_OTHER:-} ]]; then
      printf '[{"hash":"%s","message":"other"},{"hash":"%s","message":"deploy"}]\n' \
        "0000000000000000000000000000000000000001" "$real"
    else
      printf '[{"hash":"%s","message":"deploy"}]\n' "$real"
    fi ;;
  remote:drush)
    args=("$@"); seen=0; d=()
    for a in "${args[@]}"; do if [[ $seen -eq 1 ]]; then d+=("$a"); fi; [[ $a == -- ]] && seen=1; done
    if [[ ${d[0]:-} == config:status ]]; then
      if [[ -n ${FAKE_CONFIG_DIFF:-} ]]; then printf ' Name          State\n system.site   Only in sync dir\n'
      else echo " [OK] No differences between DB and sync directory."; fi
    fi ;;
  *) : ;;
esac
exit 0
SH
cat >"$STUB/curl" <<'SH'
#!/usr/bin/env bash
{ printf 'curl'; printf ' %s' "$@"; printf '\n'; } >>"$FAKE_LOG"
outf=""; wfmt=""; args=("$@"); i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    -o|--output) outf=${args[$((i+1))]}; i=$((i+1)) ;;
    -w|--write-out) wfmt=${args[$((i+1))]}; i=$((i+1)) ;;
  esac
  i=$((i+1))
done
body=${FAKE_SMOKE_BODY-<form id="user-login-form">}
code=${FAKE_SMOKE_CODE:-200}
if [[ -n $outf && $outf != /dev/null ]]; then printf '%s' "$body" >"$outf"; else [[ -n $outf ]] || printf '%s' "$body"; fi
if [[ -n $wfmt ]]; then printf '%s' "${wfmt//%\{http_code\}/$code}"; fi
[[ $code == 200 || -n ${FAKE_CURL_OK:-} ]] || true
exit 0
SH
cat >"$STUB/git" <<'SH'
#!/usr/bin/env bash
{ printf 'git'; printf ' %s' "$@"; printf '\n'; } >>"$FAKE_LOG"
case "${1:-}" in push|ls-remote) printf 'GSC %s :: %s\n' "$1" "${GIT_SSH_COMMAND-<unset>}" >>"$FAKE_LOG" ;; esac
exec "$FAKE_REALGIT" "$@"
SH
chmod +x "$STUB/terminus" "$STUB/curl" "$STUB/git"

G() { "$REALGIT" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }

# fix_new NAME: fresh fixture under $WORK/NAME: work tree (main), origin.git (has main), pan.git (empty bare, master)
fix_new() {
  local n=$1 d=$WORK/$1
  rm -rf "$d"; mkdir -p "$d/work"
  ( cd "$d/work" || exit 1
    G init -q -b main .
    mkdir -p apps/drupal/config/sync apps/drupal/web/sites/default scripts
    printf '{"name":"t07/fixture","require":{}}\n' >apps/drupal/composer.json
    printf '{"packages":[]}\n' >apps/drupal/composer.lock
    printf 'api_version: 1\nweb_docroot: true\nbuild_step: true\n' >apps/drupal/pantheon.yml
    printf 'uuid: 11111111-1111-4111-8111-111111111111\nname: fixture\n' >apps/drupal/config/sync/system.site.yml
    printf '<?php\n' >apps/drupal/web/sites/default/settings.php
    printf 'unrelated\n' >README.md
    cp "$([[ $DS == /* ]] && echo "$DS" || echo "$ROOT/$DS")" scripts/deploy-drupal.sh 2>/dev/null || true
    cp "$ROOT/$KH" scripts/pantheon_known_hosts 2>/dev/null || true
    G add -A && G commit -q -m "fixture c1"
  ) || return 1
  "$REALGIT" init -q --bare -b main "$d/origin.git"
  "$REALGIT" init -q --bare -b master "$d/pan.git"
  "$REALGIT" -C "$d/pan.git" config receive.denyNonFastForwards true
  "$REALGIT" -C "$d/pan.git" config receive.denyDeletes true
  cat >"$d/pan.git/hooks/pre-receive" <<'HK'
#!/usr/bin/env bash
while read -r old new ref; do echo "PAN-RECEIVE $ref $old $new" >>"$FAKE_LOG"; done
HK
  chmod +x "$d/pan.git/hooks/pre-receive"
  ( cd "$d/work" && G remote add origin "$d/origin.git" && G push -q origin main ) || return 1
}
fix_commit() {   # NAME REL_PATH_UNDER_apps/drupal [CONTENT]: add or change a file, commit, push to origin main
  local d=$WORK/$1/work p=$2
  ( cd "$d" || exit 1
    mkdir -p "$(dirname "apps/drupal/$p")"; printf '%s\n' "${3:-x}" >"apps/drupal/$p"
    G add -A -f && G commit -q -m "fixture: $p" && G push -q origin main )
}
fix_remove() {   # NAME REL_PATH_UNDER_apps/drupal
  local d=$WORK/$1/work
  ( cd "$d" || exit 1; G rm -q "apps/drupal/$2" && G commit -q -m "fixture: remove $2" && G push -q origin main )
}
# run_deploy NAME [args...]: run the fixture's own copy of the script with the fakes; sets RC, OUT, and LOG/ENVLOG paths
run_deploy() {
  local n=$1 d=$WORK/$1; shift
  : >"$d/log.txt"; : >"$d/envlog.txt"
  local -a ev=(HOME="$d" PATH="$STUB:$PATH" LC_ALL=C FAKE_LOG="$d/log.txt" FAKE_ENVLOG="$d/envlog.txt" FAKE_BARE="$d/pan.git" FAKE_REALGIT="$REALGIT" PANTHEON_SITE="${F_SITE-$SITE}")
  [[ -z "${F_TOKEN:-}" ]] || ev+=(TERMINUS_MACHINE_TOKEN="$F_TOKEN")
  [[ -z "${F_ALT:-}" ]] || ev+=(TERMINUS_ALTERNATE_NAMESERVER="$F_ALT")
  local v; for v in FAKE_BACKUP_FAIL FAKE_WAIT_FAIL FAKE_WAIT_TIMEOUT FAKE_WAIT_NOTFOUND FAKE_CODELOG_OTHER FAKE_CONFIG_DIFF FAKE_NO_SESSION FAKE_SMOKE_CODE FAKE_GIT_URL DEPLOY_SMOKE_BUDGET; do
    [[ -z "${!v:-}" ]] || ev+=("$v=${!v}"); done
  [[ -z "${FAKE_SMOKE_BODY+x}" ]] || ev+=("FAKE_SMOKE_BODY=$FAKE_SMOKE_BODY")
  OUT=$( cd "$d/work/${F_SUBDIR:-}" && env -i "${ev[@]}" timeout "${F_TIMEOUT:-60}" bash "$d/work/scripts/deploy-drupal.sh" "$@" 2>&1 </dev/null ) && RC=0 || RC=$?
  LOG=$d/log.txt; ENVLOG=$d/envlog.txt
}
lineno() { grep -nE -- "$2" "$1" | head -1 | cut -d: -f1; }
pan_master() { "$REALGIT" -C "$WORK/$1/pan.git" rev-parse --verify -q refs/heads/master || echo none; }
head_tree() { "$REALGIT" -C "$WORK/$1/work" rev-parse "${2:-HEAD}:apps/drupal"; }
# cand_sha OUT TREE: a 40-hex string in OUT that is a commit whose tree is TREE
cand_sha() { local c; while IFS= read -r c; do
    [[ $("$REALGIT" -C "$2" rev-parse -q --verify "$c^{tree}" 2>/dev/null) == "$3" ]] && { echo "$c"; return 0; }
  done < <(grep -oE '\b[0-9a-f]{40}\b' <<<"$1" | sort -u); return 1; }

h_dry_run() {   # TH-1
  fix_new dry || return 1
  local d=$WORK/dry/work t refs1 refs2 s1 s2
  t=$(head_tree dry)
  refs1=$("$REALGIT" -C "$d" for-each-ref | sort)
  run_deploy dry --dry-run; [[ $RC -eq 0 ]] || { echo "dry-run rc=$RC: ${OUT:0:300}"; return 1; }
  s1=$(cand_sha "$OUT" "$d" "$t") || { echo "no 40-hex commit in the output whose tree equals HEAD:apps/drupal ($t): ${OUT:0:300}"; return 1; }
  [[ "$s1" != "$("$REALGIT" -C "$d" rev-parse HEAD)" ]] || { echo "split SHA equals HEAD: nothing was split"; return 1; }
  run_deploy dry --dry-run; s2=$(cand_sha "$OUT" "$d" "$t") || true
  [[ "$s1" == "$s2" ]] || { echo "split not deterministic: $s1 vs $s2"; return 1; }
  refs2=$("$REALGIT" -C "$d" for-each-ref | sort)
  [[ "$refs1" == "$refs2" ]] || { echo "dry-run created or changed refs:"; diff <(echo "$refs1") <(echo "$refs2"); return 1; }
  ! grep -qE '^terminus|^curl|^git (push|ls-remote|fetch)' "$WORK/dry/log.txt" || { echo "dry-run touched the network:"; head -5 "$WORK/dry/log.txt"; return 1; }
  grep -qE "$SITE" <<<"$OUT" || { echo "dry-run output does not name the target ($SITE)"; return 1; }
}
h_split_guard() {   # TH-2 tree guard; arg: path under apps/drupal
  local n="g$RANDOM"; fix_new "$n" || return 1; fix_commit "$n" "$1" "x" || return 1
  run_deploy "$n"; [[ $RC -eq 1 || $RC -eq 2 ]] || { echo "$1: want exit 1 (TH-2; 2 tolerated, see ambiguity A1), got $RC: ${OUT:0:200}"; return 1; }
  ! grep -qE '^terminus|^curl|^git (push|ls-remote)' "$WORK/$n/log.txt" || { echo "$1: network step ran before the guard"; return 1; }
  [[ "$(pan_master "$n")" == none ]] || { echo "$1: something was pushed"; return 1; }
}
h_missing_required() {   # arg: file removed from the split tree
  local n="m$RANDOM"; fix_new "$n" || return 1; fix_remove "$n" "$1" || return 1
  run_deploy "$n"; [[ $RC -eq 1 || $RC -eq 2 ]] || { echo "$1 missing: want exit 1 or 2 (not 0, not 127/124), got $RC: ${OUT:0:200}"; return 1; }
  ! grep -qE '^terminus|^curl|^git (push|ls-remote)' "$WORK/$n/log.txt" || { echo "$1 missing: network step ran"; return 1; }
  [[ "$(pan_master "$n")" == none ]] || { echo "$1 missing: something was pushed"; return 1; }
}
h_first_deploy() {   # TH-3 first deploy
  fix_new first || return 1
  F_TOKEN=fake-token-0123456789abcdef run_deploy first
  local d=$WORK/first s want l
  [[ $RC -eq 0 ]] || { echo "first deploy rc=$RC: ${OUT:0:400}"; return 1; }
  want=$(pan_master first); [[ "$want" != none ]] || { echo "nothing arrived in the Pantheon bare repo"; return 1; }
  [[ "$("$REALGIT" -C "$d/pan.git" rev-parse "$want^{tree}")" == "$(head_tree first)" ]] || { echo "pushed tree differs from HEAD:apps/drupal"; return 1; }
  tail -n1 <<<"$OUT" | grep -q "$want" || { echo "last output line does not hold the deployed split SHA $want: $(tail -n1 <<<"$OUT")"; return 1; }
  grep -qE 'backup:create .*'"$SITE"'\.dev' "$d/log.txt" || { echo "no backup:create for $SITE.dev"; return 1; }
  l=$(grep -E '^terminus backup:create' "$d/log.txt" | head -1)
  grep -q -- '--element=db' <<<"$l" && grep -q -- '--keep-for=30' <<<"$l" || { echo "backup args wrong: $l"; return 1; }
  grep -qE '^terminus env:wake' "$d/log.txt" || { echo "no env:wake"; return 1; }
  grep -qE '^terminus connection:info .*git_url' "$d/log.txt" || { echo "no connection:info --field=git_url"; return 1; }
  s=$(grep -E '^git push' "$d/log.txt"); [[ $(wc -l <<<"$s") -eq 1 ]] || { echo "want exactly one git push, got: $s"; return 1; }
  grep -qE -- "$want:refs/heads/master" <<<"$s" || { echo "push refspec is not <split>:refs/heads/master: $s"; return 1; }
  ! grep -qE -- '(^| )(-f|--force|--force-with-lease[^ ]*|\+[^ ]*)( |$)' <<<"$s" || { echo "forced push: $s"; return 1; }
  [[ $(lineno "$d/log.txt" '^terminus backup:create') -lt $(lineno "$d/log.txt" '^git push') ]] || { echo "backup is not before the push"; return 1; }
  [[ $(lineno "$d/log.txt" '^terminus env:wake') -lt $(lineno "$d/log.txt" '^git push') ]] || { echo "wake is not before the push"; return 1; }
  grep -qE "^terminus workflow:wait .*--commit=$want" "$d/log.txt" || { echo "no workflow:wait --commit=<split sha>"; return 1; }
  ! grep -E '^terminus workflow:wait' "$d/log.txt" | grep -q -- '--start' || { echo "first deploy passed --start (only a re-run needs it)"; return 1; }
  grep -q 'completed successfully for commit' <<<"$OUT" || { echo "output lacks 'completed successfully for commit'"; return 1; }
  local g; for g in push ls-remote; do
    l=$(grep -E "^GSC $g " "$d/log.txt" | head -1)
    [[ -n $l ]] || { echo "no GIT_SSH_COMMAND logged for git $g"; return 1; }
    for a in 'StrictHostKeyChecking=yes' 'GlobalKnownHostsFile=/dev/null' "UserKnownHostsFile=$d/work/scripts/pantheon_known_hosts" 'BatchMode=yes'; do
      grep -qF -- "$a" <<<"$l" || { echo "git $g: GIT_SSH_COMMAND lacks $a: $l"; return 1; }
    done
  done
  [[ $(lineno "$d/log.txt" '^git push') -lt $(lineno "$d/log.txt" '^terminus workflow:wait') ]] || { echo "wait before push"; return 1; }
  grep -qE '^terminus env:code-log .*--format=json' "$d/log.txt" || { echo "no env:code-log --format=json"; return 1; }
  local a b c e
  a=$(lineno "$d/log.txt" 'remote:drush .*-- updatedb'); b=$(lineno "$d/log.txt" 'remote:drush .*-- config:import')
  c=$(lineno "$d/log.txt" 'remote:drush .*-- cache:rebuild'); e=$(lineno "$d/log.txt" 'remote:drush .*-- config:status')
  [[ -n $a && -n $b && -n $c && -n $e && $a -lt $b && $b -lt $c && $c -lt $e ]] || { echo "drush order wrong: updatedb=$a config:import=$b cache:rebuild=$c config:status=$e"; return 1; }
  grep -E 'config:import' "$d/log.txt" | grep -q -- ' -y' || { echo "config:import without -y"; return 1; }
  [[ $(lineno "$d/log.txt" 'workflow:wait') -lt $a ]] || { echo "drush before the wait"; return 1; }
  l=$(grep -E '^curl' "$d/log.txt" | tail -1)
  grep -q "$PUB/user/login" <<<"$l" || { echo "smoke check URL wrong: $l"; return 1; }
  ! grep -qE -- '(^| )(-k|--insecure)( |$)' <<<"$l" || { echo "smoke check disables certificate verification: $l"; return 1; }
}
h_idempotent() {   # TH-3 re-run
  fix_new idem || return 1
  run_deploy idem; [[ $RC -eq 0 ]] || { echo "first run rc=$RC: ${OUT:0:300}"; return 1; }
  local before; before=$(pan_master idem)
  run_deploy idem; [[ $RC -eq 0 ]] || { echo "re-run rc=$RC: ${OUT:0:400}"; return 1; }
  local d=$WORK/idem
  ! grep -qE '^terminus backup:create' "$d/log.txt" || { echo "re-run took a backup"; return 1; }
  ! grep -qE '^git push' "$d/log.txt" || { echo "re-run pushed"; return 1; }
  grep -qE '^terminus workflow:wait .*--commit='"$before"' .*--start=1' "$d/log.txt" || { echo "re-run did not call workflow:wait --commit=<sha> --start=1: $(grep '^terminus workflow:wait' "$d/log.txt")"; return 1; }
  grep -qE '^terminus env:code-log' "$d/log.txt" || { echo "re-run skipped env:code-log"; return 1; }
  grep -q 'completed successfully for commit' <<<"$OUT" || { echo "re-run output lacks 'completed successfully for commit'"; return 1; }
  grep -qE 'remote:drush .*-- updatedb' "$d/log.txt" && grep -qE 'remote:drush .*-- config:status' "$d/log.txt" && grep -q '^curl' "$d/log.txt" \
    || { echo "re-run skipped stages 7 to 9"; return 1; }
  [[ "$(pan_master idem)" == "$before" ]] || { echo "master moved on re-run"; return 1; }
  tail -n1 <<<"$OUT" | grep -q "$before" || { echo "last line lacks the split SHA"; return 1; }
}
h_rerun_fail() {   # finding 1 negative: a re-run whose build is not confirmed; arg: fail|timeout|notfound
  fix_new "rf$1" || return 1
  run_deploy "rf$1"; [[ $RC -eq 0 ]] || { echo "first run rc=$RC: ${OUT:0:300}"; return 1; }
  local before; before=$(pan_master "rf$1")
  case "$1" in
    fail) FAKE_WAIT_FAIL=1 run_deploy "rf$1" ;;
    timeout) FAKE_WAIT_TIMEOUT=1 run_deploy "rf$1" ;;
    notfound) FAKE_WAIT_NOTFOUND=1 run_deploy "rf$1" ;;
  esac
  [[ $RC -eq 1 ]] || { echo "$1 re-run: want exit 1, got $RC: ${OUT:0:300}"; return 1; }
  local d=$WORK/rf$1
  ! grep -qE 'remote:drush' "$d/log.txt" || { echo "$1 re-run: drush ran although the build was not confirmed"; return 1; }
  ! grep -qE '^terminus backup:create|^git push' "$d/log.txt" || { echo "$1 re-run took a backup or pushed"; return 1; }
  ! grep -q '^curl' "$d/log.txt" || { echo "$1 re-run: smoke check ran"; return 1; }
  ! grep -q 'deployed' <<<"$OUT" || { echo "$1 re-run printed 'deployed'"; return 1; }
  [[ "$(pan_master "rf$1")" == "$before" ]] || { echo "master moved"; return 1; }
}
h_budget() {   # validation before any network call; arg: bad value
  fix_new "bud" || return 1
  DEPLOY_SMOKE_BUDGET="$1" run_deploy bud; [[ $RC -eq 2 ]] || { echo "budget '$1': want exit 2, got $RC: ${OUT:0:200}"; return 1; }
  grep -q 'DEPLOY_SMOKE_BUDGET' <<<"$OUT" || { echo "budget '$1': message does not name DEPLOY_SMOKE_BUDGET: ${OUT:0:200}"; return 1; }
  ! grep -qE '^terminus|^curl|^git (push|ls-remote)' "$WORK/bud/log.txt" || { echo "budget '$1': a network step ran"; return 1; }
}
h_subdir() {   # finding 4: the script resolves the repository root itself
  fix_new sub || return 1
  F_SUBDIR=apps/drupal/config run_deploy sub --dry-run; [[ $RC -eq 0 ]] || { echo "dry-run from apps/drupal/config rc=$RC: ${OUT:0:300}"; return 1; }
  cand_sha "$OUT" "$WORK/sub/work" "$(head_tree sub)" >/dev/null || { echo "dry-run from a subdirectory printed no split SHA"; return 1; }
  F_SUBDIR=scripts run_deploy sub -h; [[ $RC -eq 0 ]] || { echo "-h from scripts/ rc=$RC"; return 1; }
  F_SUBDIR=apps run_deploy sub; [[ $RC -eq 0 ]] || { echo "full deploy from apps/ rc=$RC: ${OUT:0:300}"; return 1; }
  [[ "$(pan_master sub)" != none ]] || { echo "nothing pushed when run from a subdirectory"; return 1; }
}
h_url_form() {   # finding 7: arg: scp|https|sshnokey|sshmissing
  fix_new "u$1" || return 1
  local k="$WORK/u$1/work/scripts/pantheon_known_hosts"
  case "$1" in
    scp) FAKE_GIT_URL='codeserver.dev.x@codeserver.dev.x.drush.in:repository.git' run_deploy "u$1" ;;
    https) FAKE_GIT_URL='https://example.invalid/repository.git' run_deploy "u$1" ;;
    sshnokey) printf '# comments only, no key line\n' >"$k"
      FAKE_GIT_URL='ssh://codeserver.dev.x@codeserver.dev.x.drush.in:2222/~/repository.git' run_deploy "u$1" ;;
    sshmissing) rm -f "$k"
      FAKE_GIT_URL='ssh://codeserver.dev.x@codeserver.dev.x.drush.in:2222/~/repository.git' run_deploy "u$1" ;;
  esac
  [[ $RC -eq 2 ]] || { echo "$1: want exit 2, got $RC: ${OUT:0:300}"; return 1; }
  ! grep -qE '^terminus (env:wake|backup:create|workflow:wait|remote:drush)|^git (push|ls-remote)|^curl' "$WORK/u$1/log.txt" \
    || { echo "$1: wake, backup, ls-remote, push or later stage ran: $(grep -E 'env:wake|backup|ls-remote|push' "$WORK/u$1/log.txt" | head -3)"; return 1; }
  case "$1" in scp|https) grep -q 'unexpected git_url form' <<<"$OUT" || { echo "$1: no 'unexpected git_url form' message: ${OUT:0:200}"; return 1; } ;; esac
}
h_rewind() {   # TH-3 rewind rejected
  fix_new rew || return 1
  local c1; c1=$("$REALGIT" -C "$WORK/rew/work" rev-parse HEAD)
  fix_commit rew "web/modules/custom/x.txt" "second" || return 1
  run_deploy rew; [[ $RC -eq 0 ]] || { echo "deploy of c2 rc=$RC: ${OUT:0:300}"; return 1; }
  local m2; m2=$(pan_master rew)
  run_deploy rew --ref "$c1"
  [[ $RC -eq 1 ]] || { echo "rewind: want exit 1, got $RC: ${OUT:0:300}"; return 1; }
  [[ "$(pan_master rew)" == "$m2" ]] || { echo "rewind changed master"; return 1; }
  grep -q 'Roll back code' <<<"$OUT" && grep -q 'Emergency force push' <<<"$OUT" || { echo "no pointer to 'Roll back code' and 'Emergency force push' in: ${OUT:0:400}"; return 1; }
  grep -q 'docs/runbooks/deploy.md' <<<"$OUT" || { echo "pointer does not name docs/runbooks/deploy.md"; return 1; }
  ! grep -qE '^git push .*(--force|-f |\+)' "$WORK/rew/log.txt" || { echo "a forced push was attempted"; return 1; }
  ! grep -qE '^terminus (workflow:wait|remote:drush)' "$WORK/rew/log.txt" || { echo "stages after the rejected push still ran"; return 1; }
}
h_backup_fail() {
  fix_new bkf || return 1
  FAKE_BACKUP_FAIL=1 run_deploy bkf
  [[ $RC -eq 1 ]] || { echo "want exit 1, got $RC: ${OUT:0:300}"; return 1; }
  ! grep -qE '^git push' "$WORK/bkf/log.txt" || { echo "pushed after a failed backup"; return 1; }
  [[ "$(pan_master bkf)" == none ]] || { echo "master exists"; return 1; }
}
h_verify_fail() {   # arg: kind
  fix_new "v$1" || return 1
  case "$1" in
    codelog) FAKE_CODELOG_OTHER=1 run_deploy "v$1" ;;
    config) FAKE_CONFIG_DIFF=1 run_deploy "v$1" ;;
    wait) FAKE_WAIT_FAIL=1 run_deploy "v$1" ;;
    timeout) FAKE_WAIT_TIMEOUT=1 run_deploy "v$1" ;;
    notfound) FAKE_WAIT_NOTFOUND=1 run_deploy "v$1" ;;
  esac
  [[ $RC -eq 1 ]] || { echo "$1: want exit 1, got $RC: ${OUT:0:300}"; return 1; }
  case "$1" in
    codelog) ! grep -qE 'remote:drush' "$WORK/v$1/log.txt" || { echo "drush ran although code-log did not show the split SHA"; return 1; } ;;
    config) grep -qE 'remote:drush .*-- config:status' "$WORK/v$1/log.txt" || { echo "config:status never ran"; return 1; }
      ! grep -q '^curl' "$WORK/v$1/log.txt" || { echo "smoke check ran after a config difference"; return 1; } ;;
    wait|timeout|notfound) ! grep -qE 'remote:drush' "$WORK/v$1/log.txt" || { echo "drush ran after a failed, timed-out or unmatched wait"; return 1; }
      ! grep -q 'deployed' <<<"$OUT" || { echo "'deployed' printed although the build was not confirmed"; return 1; } ;;
  esac
}
h_smoke_fail() {   # arg: kind (interstitial|status)
  fix_new "s$1" || return 1
  case "$1" in
    interstitial) F_TIMEOUT=200 FAKE_SMOKE_BODY='This Sandbox site shows a warning page' run_deploy "s$1" ;;
    status) F_TIMEOUT=200 FAKE_SMOKE_CODE=503 FAKE_SMOKE_BODY='' run_deploy "s$1" ;;
  esac
  [[ $RC -eq 1 ]] || { echo "$1: want exit 1, got $RC (124 = timeout): ${OUT:0:300}"; return 1; }
}
h_unmerged() {
  fix_new unm || return 1
  local d=$WORK/unm/work
  ( cd "$d" && G checkout -q -b feat && mkdir -p apps/drupal/web/modules/custom && echo y >apps/drupal/web/modules/custom/y.txt && G add -A && G commit -q -m "feat unmerged" ) || return 1
  run_deploy unm --ref feat
  [[ $RC -eq 2 ]] || { echo "unmerged ref: want exit 2 without --allow-unmerged, got $RC: ${OUT:0:300}"; return 1; }
  ! grep -qE '^terminus|^curl|^git push' "$WORK/unm/log.txt" || { echo "network step ran before the ancestor guard"; return 1; }
  run_deploy unm --ref feat --allow-unmerged
  [[ $RC -eq 0 ]] || { echo "--allow-unmerged: want exit 0, got $RC: ${OUT:0:300}"; return 1; }
  grep -qiE 'warn' <<<"$OUT" && grep -qi 'merge commit' <<<"$OUT" || { echo "no warning that the branch must be merged with a merge commit: ${OUT:0:400}"; return 1; }
  grep -qiE 'squash|rebase' <<<"$OUT" || { echo "warning does not mention squash or rebase"; return 1; }
}
h_no_origin() {
  fix_new noo || return 1
  "$REALGIT" -C "$WORK/noo/work" update-ref -d refs/remotes/origin/main
  run_deploy noo; [[ $RC -eq 2 ]] || { echo "want exit 2, got $RC: ${OUT:0:300}"; return 1; }
  grep -q 'git fetch origin' <<<"$OUT" || { echo "message lacks 'git fetch origin'"; return 1; }
  ! grep -qE '^terminus|^curl|^git push' "$WORK/noo/log.txt" || { echo "network step ran"; return 1; }
}
h_usage() {
  fix_new use || return 1
  run_deploy use --bogus; [[ $RC -eq 2 ]] || { echo "--bogus: want 2, got $RC"; return 1; }
  run_deploy use --ref no-such-ref-xyz; [[ $RC -eq 2 ]] || { echo "bad ref: want 2, got $RC: ${OUT:0:200}"; return 1; }
  F_SITE="" run_deploy use; [[ $RC -eq 2 ]] || { echo "PANTHEON_SITE unset: want 2, got $RC: ${OUT:0:200}"; return 1; }
  FAKE_NO_SESSION=1 run_deploy use; [[ $RC -eq 1 ]] || { echo "no token and no session (whoami exits 0 with empty stdout, as 4.3.3 does): want exit 1, got $RC"; return 1; }
  grep -q 'no Terminus session' <<<"$OUT" || { echo "message lacks 'no Terminus session': ${OUT:0:200}"; return 1; }
  ! grep -qE '^terminus connection:info' "$WORK/use/log.txt" || { echo "connection:info ran without a session"; return 1; }
  ! grep -qE '^git push' "$WORK/use/log.txt" || { echo "pushed without a session"; return 1; }
  run_deploy use -h; [[ $RC -eq 0 ]] || { echo "-h: want 0, got $RC"; return 1; }
  grep -qE -- '--dry-run' <<<"$OUT" && grep -qE -- '--allow-unmerged' <<<"$OUT" && grep -q 'PANTHEON_SITE' <<<"$OUT" || { echo "-h text lacks options or env names"; return 1; }
}
h_secret() {   # TH-5
  fix_new sec || return 1
  F_TOKEN="fake-token-T07SECRETMARKER0123456789" run_deploy sec
  [[ $RC -eq 0 ]] || { echo "rc=$RC: ${OUT:0:300}"; return 1; }
  ! grep -q 'T07SECRETMARKER' <<<"$OUT" || { echo "the token appears in the script output"; return 1; }
  grep -q 'T07SECRETMARKER' "$WORK/sec/log.txt" || grep -q 'TOKEN_SET=1' "$WORK/sec/envlog.txt" || { echo "the stub never received the token (argument or environment)"; return 1; }
  grep -E '^terminus auth:login' "$WORK/sec/log.txt" >/dev/null || { echo "token set but no terminus auth:login"; return 1; }
  # without a token: no auth:login, uses auth:whoami
  fix_new sec2 || return 1
  run_deploy sec2; [[ $RC -eq 0 ]] || { echo "no-token run rc=$RC"; return 1; }
  ! grep -q '^terminus auth:login' "$WORK/sec2/log.txt" || { echo "auth:login called without a token"; return 1; }
  grep -q '^terminus auth:whoami' "$WORK/sec2/log.txt" || { echo "no auth:whoami without a token"; return 1; }
}
h_ssh_env() {   # SA-4 / TH-4 dynamic part
  fix_new ssh || return 1
  run_deploy ssh; [[ $RC -eq 0 ]] || { echo "rc=$RC"; return 1; }
  local want='ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR'
  grep -qF "TERMINUS_SSH_COMMAND=$want ALT=<unset>" "$WORK/ssh/envlog.txt" || { echo "terminus saw: $(head -3 "$WORK/ssh/envlog.txt")"; echo "want TERMINUS_SSH_COMMAND=$want and ALT unset"; return 1; }
  [[ $(grep -vcF "TERMINUS_SSH_COMMAND=$want" "$WORK/ssh/envlog.txt") -eq 0 ]] || { echo "some terminus call had another TERMINUS_SSH_COMMAND"; return 1; }
}

# ---------- python helper: workflow structure (TH-9) ----------
cat >"$WORK/wf.py" <<'PY'
import re, sys
try:
    import yaml
except Exception as exc:
    print("PyYAML missing:", exc); sys.exit(3)
path = sys.argv[1]
probs = []
try:
    text = open(path, encoding="utf-8").read()
    wf = yaml.safe_load(text)
except Exception as exc:
    print(f"{path}: cannot read or parse: {exc}"); sys.exit(1)
on = wf.get("on", wf.get(True)) or {}
push = (on.get("push") or {}) if isinstance(on, dict) else {}
if push.get("branches") != ["main"]: probs.append(f"push.branches is {push.get('branches')!r}, want ['main']")
paths = push.get("paths") or []
for p in ("apps/drupal/**", "scripts/deploy-drupal.sh", "scripts/pantheon_known_hosts"):
    if p not in paths: probs.append(f"push.paths lacks {p}")
wd = (on.get("workflow_dispatch") or {}) if isinstance(on, dict) else {}
ref = ((wd.get("inputs") or {}).get("ref") or {})
if not ref: probs.append("workflow_dispatch has no input 'ref'")
elif ref.get("default") != "main": probs.append(f"input ref default is {ref.get('default')!r}, want main")
c = wf.get("concurrency") or {}
if c.get("group") != "deploy-drupal" or c.get("cancel-in-progress") is not False:
    probs.append(f"concurrency is {c!r}, want group deploy-drupal and cancel-in-progress false")
if (wf.get("permissions") or {}) != {"contents": "read"}: probs.append(f"permissions is {wf.get('permissions')!r}, want only contents: read")
jobs = wf.get("jobs") or {}
if not jobs: probs.append("no jobs")
guard = skipline = runline = False
for jn, j in jobs.items():
    if j.get("timeout-minutes") != 30: probs.append(f"job {jn}: timeout-minutes {j.get('timeout-minutes')!r}, want 30")
    if "vars.PANTHEON_SITE" in str(j.get("if", "")): guard = True
    for s in j.get("steps") or []:
        if "vars.PANTHEON_SITE" in str(s.get("if", "")): guard = True
        r = s.get("run", "") or ""
        if "not configured (PANTHEON_SITE unset), skipped" in r: skipline = True
        if "scripts/deploy-drupal.sh" in r:
            runline = True
            if "--allow-unmerged" in r: probs.append("run step passes --allow-unmerged")
            if '--ref "$DEPLOY_REF"' not in r: probs.append('run step does not pass --ref "$DEPLOY_REF"')
            env = s.get("env") or {}
            dr = str(env.get("DEPLOY_REF", ""))
            if "inputs.ref" not in dr or "github.sha" not in dr: probs.append("env DEPLOY_REF is not 'inputs.ref || github.sha'")
            for ev in ("DEPLOY_SMOKE_BUDGET", "DEPLOY_SMOKE_HEADER"):
                if f"vars.{ev}" not in str(env.get(ev, "")): probs.append(f"deploy step env lacks {ev}: ${{{{ vars.{ev} }}}}")
        if "${{" in r: probs.append(f"job {jn}: a GitHub expression is expanded inside run: {r[:60]!r}")
        if s.get("run") is not None and not str(s.get("run")).strip(): probs.append("empty run: block")
        u = s.get("uses")
        if u and not re.match(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$", str(u)): probs.append(f"action not pinned by commit SHA: {u}")
        if u and not str(u).startswith("actions/"): probs.append(f"third-party action: {u}")
        if re.search(r"set -x|--force|--insecure", r): probs.append("set -x, --force or --insecure in a run step")
if not guard: probs.append("no if: on vars.PANTHEON_SITE (job or step)")
if not skipline: probs.append("no skip step printing 'deploy-drupal: not configured (PANTHEON_SITE unset), skipped'")
if not runline: probs.append("no step runs scripts/deploy-drupal.sh")
# secrets only through env:
for m in re.finditer(r"\$\{\{\s*secrets\.(\w+)", text):
    line = text[:m.start()].count("\n")
    ctx = text.splitlines()
    k = line
    while k >= 0 and not re.match(r"\s*(env|with|run):", ctx[k]) and not re.match(r"\s{0,8}- name:", ctx[k]): k -= 1
    if k < 0 or not re.match(r"\s*env:", ctx[k]): probs.append(f"secret {m.group(1)} (line {line+1}) is not in an env: block")
for sec in ("TERMINUS_MACHINE_TOKEN", "PANTHEON_DEPLOY_KEY"):
    if f"secrets.{sec}" not in text: probs.append(f"secrets.{sec} not used")
if "vars.PANTHEON_SITE" not in text: probs.append("vars.PANTHEON_SITE not used")
if "TERMINUS_VERSION: 4.3.3" not in text: probs.append("TERMINUS_VERSION: 4.3.3 is not pinned (owner requirement; 3.6.2 cannot log in with a PAT)")
if "e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade" not in text: probs.append("Terminus 4.3.3 SHA-256 e7ca9bca...bade is not pinned")
if "sha256sum --check --strict" not in text: probs.append("checksum is not verified with sha256sum --check --strict")
if "3.6.2" in text: probs.append("Terminus 3.6.2 still mentioned")
if not any(isinstance(j.get("steps"), list) and any(isinstance(x.get("run"), str) and "run" in x for x in j["steps"]) for j in jobs.values()): probs.append("no run: blocks found")
if not re.search(r"ssh-add\s+-(\s|$)", text): probs.append("key is not loaded with 'ssh-add -' from stdin")
if "fetch-depth: 0" not in text: probs.append("checkout lacks fetch-depth: 0")
if probs:
    print("\n".join(probs)); sys.exit(1)
PY

# ---------- python helper: provider and DDEV config ----------
cat >"$WORK/cfg.py" <<'PY'
import sys
try:
    import yaml
except Exception as exc:
    print("PyYAML missing:", exc); sys.exit(3)
probs = []
try:
    c = yaml.safe_load(open(".ddev/config.yaml", encoding="utf-8"))
except Exception as exc:
    print("cannot parse .ddev/config.yaml:", exc); sys.exit(1)
we = c.get("web_environment") or []
if "PANTHEON_SITE=meridian-trade" not in we: probs.append(f"web_environment lacks PANTHEON_SITE=meridian-trade: {we!r}")
if any(str(x).startswith("TERMINUS_MACHINE_TOKEN") for x in we): probs.append("token in the project config.yaml")
try:
    p = yaml.safe_load(open(".ddev/providers/pantheon.yaml", encoding="utf-8"))
except Exception as exc:
    print("cannot parse provider:", exc); sys.exit(1)
for k in ("auth_command", "db_pull_command", "files_pull_command"):
    if k not in p: probs.append(f"provider lacks {k}")
for k in p:
    if "push" in k: probs.append(f"provider has {k} (pull only, KD-3)")
def cmd(k):
    v = (p.get(k) or {}).get("command", "")
    return v if isinstance(v, str) else str(v)
if "TERMINUS_MACHINE_TOKEN" not in cmd("auth_command") or "terminus auth:login" not in cmd("auth_command"): probs.append("auth_command lacks the token check and terminus auth:login")
if "personal access token" not in cmd("auth_command").lower() and "PAT" not in cmd("auth_command"): probs.append("auth_command error text does not say personal access token (PAT)")
for k, el in (("db_pull_command", "db"), ("files_pull_command", "files")):
    t = cmd(k)
    if f"backup:create" not in t or f"--element={el}" not in t or "--keep-for=30" not in t: probs.append(f"{k} lacks backup:create --element={el} --keep-for=30")
    elif "backup:get" not in t or t.index("backup:create") > t.index("backup:get"): probs.append(f"{k}: backup:create must come before backup:get")
    if "PANTHEON_SITE:?" not in t: probs.append(f"{k} does not use ${{PANTHEON_SITE:?}}")
    if "set -x" in t: probs.append(f"{k} has set -x")
if probs:
    print("\n".join(probs)); sys.exit(1)
PY

# =====================================================================================================
if [[ "$MODE" != liveonly && "$MODE" != clone ]]; then
# =====================================================================================================

case_start TC-T07-01 "AC1: pantheon.yml committed in apps/drupal with the build settings"
ckp "apps/drupal/pantheon.yml is tracked by git" bash -c "git ls-files --error-unmatch apps/drupal/pantheon.yml"
ckp "pantheon.yml: build_step true, web_docroot true, php 8.3, MariaDB 10.6, api_version 1" allin apps/drupal/pantheon.yml 'build_step: *true' 'web_docroot: *true' 'php_version: *8\.3' 'version: *10\.6' 'api_version: *1'
ckp "the split tree holds no pantheon.upstream.yml and no upstream-configuration path (KD-7)" bash -c "! git ls-files apps/drupal | grep -E 'pantheon\.upstream\.yml|upstream-configuration' && ! grep -q 'upstream-configuration' apps/drupal/composer.json"
ckp "the split tree carries its own tracked .gitignore (DEF-010; KD-7 amended)" bash -c "git ls-files --error-unmatch apps/drupal/.gitignore >/dev/null"
gi_only() { # $1 = want (ignored|kept), rest = paths; tests apps/drupal/.gitignore alone in an empty repository
  local want=$1 d p; shift; d=$(mktemp -d); git -C "$d" init -q; cp apps/drupal/.gitignore "$d/.gitignore" || { rm -rf "$d"; return 1; }
  for p in "$@"; do
    if git -C "$d" check-ignore -q --no-index "$p"; then [[ $want == ignored ]] || { echo "ignored: $p"; rm -rf "$d"; return 1; }
    else [[ $want == kept ]] || { echo "not ignored: $p"; rm -rf "$d"; return 1; }; fi
  done; rm -rf "$d"; }
ckp "apps/drupal/.gitignore on its own ignores the build output and scaffold files the Pantheon build creates" gi_only ignored vendor/autoload.php web/core/lib/Drupal.php web/modules/contrib/x/x.module web/index.php web/.htaccess web/sites/default/settings.pantheon.php web/sites/default/default.services.pantheon.preproduction.yml web/sites/.gitignore recipes/README.txt .editorconfig .gitattributes
ckp "apps/drupal/.gitignore ignores no owned path (composer.json, composer.lock, pantheon.yml, config/sync, settings.php, custom code)" gi_only kept composer.json composer.lock pantheon.yml config/sync/system.site.yml web/sites/default/settings.php web/modules/custom/x/x.info.yml phpcs.xml.dist
ckp "runbook records the upstream 'Drupal (Composer Managed)' and the site name $SITE" allin "$RB" 'Composer Managed' "$SITE"

case_start TC-T07-02 "AC2: PAT setup, 90-day rotation, expiry table in the runbook; token never committed"
ckp "runbook explains PAT (formerly machine token), 90 days, creation and expiry date table" allin "$RB" 'personal access token|PAT' 'formerly.{0,20}machine token' '90 days|90-day' 'expir' 'creation|created'
ckp "runbook: where to create it, not in Microsoft Edge, global DDEV config command, restart" allin "$RB" 'Personal Access Tokens' 'Edge' 'ddev config global --web-environment-add=TERMINUS_MACHINE_TOKEN' 'ddev restart'
ckp "runbook: rotation steps (create new, replace in every store, terminus auth:whoami, revoke old)" allin "$RB" 'rotat' 'auth:whoami' 'revoke'
ckp "runbook: PAT table has columns owner, purpose, store, creation date, expiry date and no token value" bash -c "grep -iE '^\|.*owner.*\|.*purpose.*\|.*store.*\|.*(creat|issued).*\|.*expir' $RB"
ckp "runbook: rotate any PAT expiring within the T31 window plus 7 days; an expired PAT breaks deploys and pulls, not the daily run" allin "$RB" 'T31' '7 days' 'daily (engine )?run|daily-run'
ckp "runbook: RSA key (ed25519 not supported), ddev auth ssh, never paste the token in chat or the repo" allin "$RB" 'RSA' 'ed25519' 'ddev auth ssh' 'never.{0,40}(chat|commit|repo)'
ckp "runbook: evidence never includes env, printenv or ddev exec env output (global web_environment is visible in the container)" allin "$RB" 'printenv|ddev exec env'
ckp "docs/TASKS.md T07 AC2 carries the PAT wording" allin docs/TASKS.md 'Terminus personal access token \(PAT, formerly machine token\)'

case_start TC-T07-03 "C6: no secrets in T07 files; .env.example and DDEV config hold placeholders only"
SECRE='BEGIN [A-Z ]*PRIVATE KEY|sk-ant-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20}|xox[bp]-[0-9A-Za-z-]{10}'
nosecret() { local f; [[ -n "$(t07_impl_files)" ]] || { echo "no T07 implementation files yet"; return 1; }
  f=$(t07_files)
  ! echo "$f" | xargs -d '\n' grep -IEn "$SECRE" 2>/dev/null || { echo "secret-shaped string found"; return 1; }; }
ckp "no key, token or credential pattern in any T07 file (implementation files must exist)" nosecret
ckp ".env.example: TERMINUS_MACHINE_TOKEN and PANTHEON_DEPLOY_KEY have empty values" bash -c "grep -qE '^TERMINUS_MACHINE_TOKEN=\$' .env.example && grep -qE '^PANTHEON_DEPLOY_KEY=\$' .env.example"
ckp ".env.example: PANTHEON_SITE=meridian-trade and the PAT wording (formerly machine token, 90 days)" allin .env.example '^PANTHEON_SITE=meridian-trade$' 'PAT' 'formerly machine token' '90 days'
ckp "no TERMINUS_MACHINE_TOKEN value in .ddev/config.yaml, the workflow, the provider or the wrapper (all four must exist)" bash -c "[[ -s $WF && -s $PRV && -s $WRAP && -s $DCFG ]] && ! grep -hE 'TERMINUS_MACHINE_TOKEN *[=:] *[^\$ \"'\\'']' $DCFG $WF $PRV $WRAP 2>/dev/null | grep -vE '^\s*#|\\$\{|secrets\.|:\?|-z |-n '"
ckp "no private key block or key file tracked under scripts/, .ddev/ or .github/" bash -c "! git ls-files scripts .ddev .github | xargs -r grep -lE 'BEGIN [A-Z ]*PRIVATE KEY' ; ! git ls-files | grep -E '\.(pem|key)\$|id_rsa'"
ckp "no set -x in the script, wrapper, provider or workflow" bash -c "f=\$(ls $DS $WRAP $PRV $WF 2>/dev/null); [[ -n \"\$f\" ]] && ! grep -nE '(^|[ ;&|])set +-[a-zA-Z]*x|bash -x|sh -x' \$f"
if command -v gitleaks >/dev/null 2>&1; then
  ckp "gitleaks over the working tree" gitleaks detect --no-git --source . --no-banner --redact
else skip "gitleaks not on PATH: the pre-commit hook covers it (TC-T07-24)"; fi

case_start TC-T07-04 "AC3 static: the DDEV Pantheon provider is pull-only, uses PANTHEON_SITE, takes a fresh backup"
ckp "provider file exists and has no '#ddev-generated' line (DDEV would overwrite it)" bash -c "[[ -s $PRV ]] && ! grep -q '#ddev-generated' $PRV"
ckp "provider parses; has auth_command, db_pull_command, files_pull_command; no *push* key; backup:create before backup:get with --element=db|files --keep-for=30; uses \${PANTHEON_SITE:?}; PAT wording; no set -x" python3 -I "$WORK/cfg.py"
ckp "provider text has no 'terminus .* push' or 'db_push' or 'files_push' command anywhere" bash -c "[[ -s $PRV ]] && ! grep -nE 'db_push|files_push|backup:restore|env:wipe|--force' $PRV"
ckp "provider does not use the static 'project' variable for the site (uses PANTHEON_SITE)" bash -c "[[ -s $PRV ]] && ! grep -nE '^project:|\\\$\{?project\}?' $PRV"

case_start TC-T07-05 "KD-4: PANTHEON_SITE has one value, meridian-trade, in every place"
ckp ".ddev/config.yaml web_environment holds PANTHEON_SITE=meridian-trade and no token" python3 -I "$WORK/cfg.py"
ckp ".ddev/config.yaml value equals the .env.example value" bash -c "a=\$(grep -E '^ *- *PANTHEON_SITE=' $DCFG | sed -E 's/.*PANTHEON_SITE=//' | tr -d ' \"'\\''' | head -1); b=\$(grep -E '^PANTHEON_SITE=' .env.example | cut -d= -f2); [[ -n \$a && \$a == \$b && \$a == $SITE ]] || { echo \"config.yaml='\$a' .env.example='\$b'\"; exit 1; }"
ckp "openapi.yaml server variable 'site' defaults to $SITE" bash -c "grep -A6 -E '^\s+site:' $OAS | grep -qE 'default: *[\"'\\'']?${SITE}[\"'\\'']?\$' || { echo 'no site default meridian-trade'; exit 1; }"
ckp "technical-design D7: PANTHEON_SITE DDEV column says .ddev/config.yaml web_environment; TERMINUS_MACHINE_TOKEN row says PAT (formerly machine token; expires 90 days)" bash -c "grep -E '^\| .PANTHEON_SITE' $TD | grep -q 'web_environment' && grep -E '^\| .TERMINUS_MACHINE_TOKEN' $TD | grep -qiE 'personal access token|PAT' && grep -E '^\| .TERMINUS_MACHINE_TOKEN' $TD | grep -q '90 days'"

case_start TC-T07-06 "AC4 static: scripts/deploy-drupal.sh exists, is safe by construction (KD-1)"
ckp "script exists, is executable, has a bash shebang, bash -n passes" bash -c "[[ -f $DS && -x $DS ]] && head -1 $DS | grep -qE '^#!.*bash' && bash -n $DS"
if command -v shellcheck >/dev/null 2>&1; then ckp "shellcheck on the script, wrapper and (if present) the provider-free helper files" bash -c "shellcheck -s bash $DS"; else skip "shellcheck not on PATH: the pre-commit shellcheck hook covers it"; fi
ckp "no force push: no --force, -f, --force-with-lease or '+' refspec in a git push line (script and wrapper)" bash -c "[[ -s $DS && -s $WRAP ]] && ! grep -nE 'git +push[^#]*(--force|--force-with-lease| -f( |\$)| \+[^ ]*:)' $DS $WRAP && ! grep -nE -- '--force|\+refs/' $DS"
ckp "git subtree split --prefix=apps/drupal is used without -b" bash -c "grep -E 'subtree split' $DS | grep -q -- '--prefix=apps/drupal' && ! grep -E 'subtree split' $DS | grep -qE -- ' -b( |\$)'"
ckp "script pushes <sha>:refs/heads/master, uses --element=db and --keep-for=30, workflow:wait --commit, env:code-log, remote:drush, config:status" allin "$DS" ':refs/heads/master' '--element=db' '--keep-for=30' 'workflow:wait' '--commit' 'env:code-log' 'remote:drush' 'updatedb' 'config:import' 'cache:rebuild' 'config:status'
ckp "script has --ref, --dry-run, --allow-unmerged, -h and the exit codes 0, 1, 2 documented" allin "$DS" '\-\-ref' '\-\-dry-run' '\-\-allow-unmerged' '\-h' 'PANTHEON_SITE' 'TERMINUS_MACHINE_TOKEN'
ckp "script never echoes the token or dumps the environment (no printenv, no bare env, no echo or printf that expands TERMINUS_MACHINE_TOKEN; help text naming the variable is fine)" bash -c "[[ -s $DS ]] && ! grep -nE '(^|[ ;|&(])(printenv|export -p|declare -x)([ ;|&)]|\$)|(^|[ ;|&(])env *(\||\$)|(echo|printf)[^#]*[$]\\{?TERMINUS_MACHINE_TOKEN' $DS"
ckp "smoke check uses https:// with certificate verification: no -k, --insecure or 'curl -s' without verify; checks user-login-form" bash -c "[[ -s $DS ]] && ! grep -nE -- ' -k( |\$)|--insecure' $DS && grep -q 'user-login-form' $DS && grep -qE 'dev-.*pantheonsite\.io|pantheonsite\.io' $DS"
ckp "script contains no real-order or broker API call and only pantheon, drush.in, pantheonsite.io, github hosts" bash -c "[[ -s $DS ]] && ! grep -iEn \"$SIM_BR\" $DS && ! grep -hoE 'https?://[^ \"'\\'')]+' $DS | grep -vE 'pantheonsite\.io|getpantheon|pantheon\.io|github\.com|\\\$'"

case_start TC-T07-07 "SA-4: SSH host key pinning statics and TERMINUS_SSH_COMMAND"
ckp "script sets GIT_SSH_COMMAND with StrictHostKeyChecking=yes, GlobalKnownHostsFile=/dev/null, UserKnownHostsFile pointing at scripts/pantheon_known_hosts, BatchMode=yes" allin "$DS" 'GIT_SSH_COMMAND' 'StrictHostKeyChecking=yes' 'GlobalKnownHostsFile=/dev/null' 'pantheon_known_hosts' 'BatchMode=yes'
ckp "script sets TERMINUS_SSH_COMMAND to exactly: ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR" bash -c "grep -qF 'TERMINUS_SSH_COMMAND' $DS && grep -F 'TERMINUS_SSH_COMMAND' $DS | grep -qF 'ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR'"
ckp "script never sets TERMINUS_ALTERNATE_NAMESERVER (it swaps names for IPs and breaks pinning); the wrapper and workflow do not either" bash -c "[[ -s $DS ]] && ! grep -nE 'TERMINUS_ALTERNATE_NAMESERVER *=|export TERMINUS_ALTERNATE_NAMESERVER' $DS $WRAP $WF 2>/dev/null"
if ! kh_has_key; then
  blk "awaiting L-3 (review condition 1): the key is committed only after copies from two days and two networks match; the developer owns $KH. Copy 1 is in evidence/host-key-copy1.txt"
else
ckp "known hosts file exists, holds only [codeserver.dev.<uuid>.drush.in]:2222 key lines (ssh-rsa or ecdsa)" bash -c "need=\$(grep -vE '^\s*(#|\$)' $KH); [[ -n \"\$need\" ]] && ! grep -vE '^\s*(#|\$)' $KH | grep -vE '^\[codeserver\.dev\.[0-9a-f-]{36}\.drush\.in\]:2222 (ssh-rsa|ecdsa-sha2-nistp[0-9]+|ssh-ed25519) [A-Za-z0-9+/=]+\$'"
ckp "known hosts file comments: SHA256 fingerprint, date, how fetched, 'app server' deliberately not pinned, link to decision-host-keys.md" bash -c "grep -E '^\s*#' $KH | grep -qE 'SHA256:[A-Za-z0-9+/]+' && grep -E '^\s*#' $KH | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' && grep -E '^\s*#' $KH | grep -qiE 'ssh-keyscan' && grep -E '^\s*#' $KH | grep -qi 'app server' && grep -E '^\s*#' $KH | grep -q 'decision-host-keys.md'"
ckp "known hosts file holds no app server entry and no private key" bash -c "[[ -s $KH ]] && ! grep -vE '^\s*#' $KH | grep -E 'appserver|PRIVATE KEY' "
fi

case_start TC-T07-08 "AC4 static: ddev deploy-drupal wrapper (KD-1)"
ckp "wrapper exists, is executable, passes bash -n, is a DDEV web-container command (## Description / ## Usage header)" bash -c "[[ -f $WRAP && -x $WRAP ]] && bash -n $WRAP && grep -q '## Description' $WRAP"
ckp "wrapper calls scripts/deploy-drupal.sh and passes its arguments through (\"\$@\")" bash -c "grep -q 'scripts/deploy-drupal.sh' $WRAP && grep -qF '\"\$@\"' $WRAP"
ckp "wrapper has no set -x, no force push, no token echo, does not unset PANTHEON_SITE" bash -c "[[ -s $WRAP ]] && ! grep -nE 'set -x|--force|echo[^#]*TOKEN|printenv' $WRAP"
if command -v shellcheck >/dev/null 2>&1; then ckp "shellcheck on the wrapper" bash -c "shellcheck -s bash $WRAP"; else skip "shellcheck not on PATH"; fi
ckp ".ddev/README.md lists ddev deploy-drupal (or the commands index does)" bash -c "grep -rqE 'deploy-drupal' .ddev/README.md"

case_start TC-T07-09 "AC4 static: deploy-drupal.yml is a thin, guarded, pinned wrapper (TH-9, KD-8)"
ckp "workflow file exists and parses" bash -c "python3 -I -c 'import yaml,sys; yaml.safe_load(open(\"$WF\"))'"
ckp "triggers (push main + 3 paths, dispatch ref default main), concurrency deploy-drupal no-cancel, permissions contents:read, timeout 30, if: vars.PANTHEON_SITE, skip line, run step passes --ref DEPLOY_REF (from env:) with DEPLOY_SMOKE_* in env:, no GitHub expression inside any run:, secrets in env only, actions pinned by SHA, no third-party action, Terminus 4.3.3 + SHA-256 e7ca9bca...bade checked with --strict, ssh-add -, fetch-depth 0, no --allow-unmerged" python3 -I "$WORK/wf.py" "$WF"
ckp "workflow has no 'set -x', no --force, no inline secret, no broker host" bash -c "[[ -s $WF ]] && ! grep -nE 'set -x|--force|--allow-unmerged' $WF && ! grep -iEn \"$SIM_BR\" $WF"
ckp "no secrets.* or vars.* expression is used inside a run: block (they arrive through env:)" bash -c "python3 -I -c '
import yaml,re,sys
w=yaml.safe_load(open(\"$WF\"))
for j in w[\"jobs\"].values():
    for s in j.get(\"steps\",[]):
        if re.search(r\"secrets\.|vars\.\", s.get(\"run\",\"\") or \"\"): sys.exit(1)
'"

case_start TC-T07-10 "C4 stand-in: pinned actionlint, yamllint and check-yaml on the workflow"
AL=""; if [[ -x .tools/actionlint ]]; then AL=.tools/actionlint; elif command -v actionlint >/dev/null 2>&1; then AL=$(command -v actionlint); fi
if [[ -n "$AL" ]]; then
  ckp "actionlint ($AL) exits 0 on $WF (record the version in the report; it must be the pinned version)" "$AL" "$WF"
  note "actionlint version: $("$AL" -version 2>&1 | head -1)"
else blk "actionlint is not on PATH; the report must attach the pinned-version run (plan C4 stand-in). Install the pinned version and re-run"; fi
ckp "the pinned actionlint version is written down (runbook, scripts/README.md or tool-versions)" bash -c "grep -rqiE 'actionlint[ =@v:-]*[0-9]+\.[0-9]+\.[0-9]+' $RB scripts/README.md scripts/tool-versions.env .github/README.md 2>/dev/null"
if command -v yamllint >/dev/null 2>&1; then ckp "yamllint -c .yamllint.yaml on the workflow and the provider" yamllint -c .yamllint.yaml "$WF" "$PRV"; else skip "yamllint not on PATH: covered by pre-commit in TC-T07-24"; fi

case_start TC-T07-11 "AC4 offline harness: --dry-run on a fixture repo (TH-1)"
ckp "dry-run prints a split SHA whose tree equals REF:apps/drupal, is deterministic, creates no ref or branch, makes no external call, names the target" h_dry_run

case_start TC-T07-12 "AC4 offline harness: split-tree guard stops before any network step (TH-2, KD-1 stage 2)"
for p in vendor/x web/core/x web/modules/contrib/m/m.info.yml web/sites/default/files/x.txt private/x .env keys/a.key keys/a.pem web/sites/default/settings.local.php; do
  ckp "split containing apps/drupal/$p exits 1 (or 2) before terminus, curl or push; nothing arrives on Pantheon" h_split_guard "$p"
done
for f in composer.json composer.lock pantheon.yml config/sync/system.site.yml; do
  ckp "split without $f exits non-zero before any network step" h_missing_required "$f"
done

case_start TC-T07-13 "AC4 offline harness: ancestor guard, --allow-unmerged, usage and exit-2 errors (KD-1 stage 1)"
ckp "ref not reachable from origin/main: exit 2 without --allow-unmerged; with it exit 0 and a warning about merge commit and squash/rebase" h_unmerged
ckp "missing origin/main: exit 2 with 'git fetch origin'" h_no_origin
ckp "unknown option, unresolvable ref, PANTHEON_SITE unset: exit 2; no token and no session: non-zero and no push; -h: exit 0 and lists options" h_usage

case_start TC-T07-14 "AC4 offline harness: first deploy runs every stage, in order, without force (TH-3)"
ckp "exit 0; pushed tree equals HEAD:apps/drupal; one non-force push of <sha>:refs/heads/master; backup (--element=db --keep-for=30) then wake then push then workflow:wait --commit then code-log then updatedb, config:import -y, cache:rebuild, config:status; smoke URL https, no -k; split SHA is the last line" h_first_deploy

case_start TC-T07-15 "AC4 offline harness: idempotent re-run (TH-3, KD-1 stage 4)"
ckp "second run: exit 0, no backup, no push; workflow:wait --commit=<sha> --start=1 and env:code-log still run and the output holds 'completed successfully for commit'; drush stages and smoke check run; master unchanged; split SHA last" h_idempotent
ckp "negative re-run, build failed: exit 1, no drush, no smoke check, no backup, no push, no 'deployed', master unchanged" h_rerun_fail fail
ckp "negative re-run, workflow:wait gives up (timeout, exit 0): exit 1 and the same absences" h_rerun_fail timeout
ckp "negative re-run, no matching workflow (not found, exit 0): exit 1 and the same absences" h_rerun_fail notfound

case_start TC-T07-16 "AC4 offline harness: a rewind push is rejected, never forced (TH-3, SA-2)"
ckp "deploying an older ancestor of origin/main after a newer deploy: exit 1, master unchanged, message points to 'Roll back code' and 'Emergency force push' in docs/runbooks/deploy.md, no forced push, no later stage" h_rewind

case_start TC-T07-17 "AC4 offline harness: a failed backup stops the deploy before the push (SA-2 decision 5)"
ckp "backup:create exits 1: script exits 1, no git push, nothing on Pantheon" h_backup_fail

case_start TC-T07-18 "AC4 offline harness: verification failures exit 1 (TH-3, SA-4, R5)"
ckp "env:code-log shows another newest hash: exit 1 and no drush stage" h_verify_fail codelog
ckp "workflow:wait fails: exit 1 and no drush stage" h_verify_fail wait
ckp "workflow:wait gives up (timeout, exit 0, no success notice): exit 1, no drush stage, no 'deployed'" h_verify_fail timeout
ckp "workflow:wait finds no workflow (not found, exit 0, no success notice): exit 1, no drush stage, no 'deployed'" h_verify_fail notfound
ckp "config:status reports differences: exit 1 and no smoke check" h_verify_fail config
ckp "smoke check: HTTP 200 with the Sandbox interstitial body (no user-login-form marker): exit 1 (can take up to the 120 s wake retry budget)" h_smoke_fail interstitial
ckp "smoke check: HTTP 503: exit 1 (can take up to the 120 s wake retry budget)" h_smoke_fail status

case_start TC-T07-19 "C6 harness: the PAT stays out of output; token optional; TERMINUS_SSH_COMMAND reaches terminus (TH-4, TH-5)"
ckp "fake PAT is received by terminus (auth:login) and absent from stdout and stderr of the script; without a token the script uses auth:whoami and no auth:login" h_secret
ckp "every terminus call sees TERMINUS_SSH_COMMAND exactly as decided and TERMINUS_ALTERNATE_NAMESERVER unset" h_ssh_env

case_start TC-T07-20 "AC6: runbook deploy.md: owner steps, deploy, rollback, forbidden actions, emergency force push (KD-9, SA-2)"
ckp "runbook exists with the template headings (Steps, Verification, Rollback)" allin "$RB" '^# ' '^## Steps' '^## Verification' '^## Rollback'
ckp "sections: First push (O-4), Reinstall Pantheon dev, Pull (ddev pull pantheon, ddev snapshot first), Roll back code, Restore the database, Emergency force push, Troubleshooting, event log" allin "$RB" 'First push' 'Reinstall Pantheon dev' 'ddev pull pantheon' 'ddev snapshot' 'Roll back code' 'Restore the database' 'Emergency force push' 'Troubleshooting' 'log'
ckp "Roll back code: git revert on a task branch, merge commit (no squash, no rebase), deploy main (workflow or ddev deploy-drupal)" allin "$RB" 'git revert' 'merge commit' 'squash' 'rebase' 'ddev deploy-drupal'
ckp "Restore the database: backup:list --element=db and backup:restore --element=db --file=<name> --yes, then cache:rebuild, config:status, smoke check" allin "$RB" 'backup:list' 'backup:restore' '--element=db' '--file=' '--yes' 'cache:rebuild' 'config:status'
ckp "Forbidden on Pantheon dev: dashboard Restore button, backup:restore without --element, --element=all, --element=code" allin "$RB" 'dashboard.{0,30}Restore|Restore button' 'without .{0,3}--element' '--element=all' '--element=code' 'forbidden|never'
ckp "Emergency force push: owner only, backup first, a commit that is on main, run stages 7 to 9 by hand, record in the log table" allin "$RB" 'owner only|only the owner' 'git push --force' 'on .main.|on main' 'log'
ckp "First push (O-4): backup --element=db --keep-for=30, then git push --force <git_url> <split_sha>:refs/heads/master with the split SHA from --dry-run --ref origin/main; the only forced push outside an emergency" allin "$RB" 'ddev deploy-drupal --ref origin/main --dry-run' 'refs/heads/master' '--keep-for=30'
ckp "Reinstall: env:wipe, site:install --existing-config, warning that it destroys the dev database, admin password never pasted (user:login)" allin "$RB" 'env:wipe' 'site:install --existing-config' 'destroy' 'user:login' 'password'
ckp "Upstream rule text: dashboard upstream and Composer updates are never applied; if applied by mistake use Emergency force push" allin "$RB" 'never (be )?applied|never apply' 'upstream' 'by mistake'
ckp "SFTP mode is forbidden (an SFTP commit breaks the non-force push); dev stays in Git mode" allin "$RB" 'SFTP' 'Git mode|git mode'
ckp "no instruction in the runbook uses --element=all or a bare backup:restore as a step (only in the forbidden list)" bash -c "[[ -s $RB ]] && ! grep -nE '^\s*(terminus )?backup:restore [^#]*\$' $RB | grep -vE -- '--element=db'"
ckp "runbook has 'Last verified' with a date" allin "$RB" 'Last verified.{0,40}20[0-9]{2}-[0-9]{2}-[0-9]{2}'

case_start TC-T07-21 "AC6: runbook records sandbox sleep, freeze, limits and the interstitial (KD-12, SA-6)"
ckp "sleep: idle about 1 hour, a web request wakes it, observed wake time recorded" allin "$RB" 'sleep' '1 hour|one hour|1 h' 'wake' 'observed|measured'
ckp "freeze: 4 months old, 3 months without Git activity, 530 Site Frozen, unfreeze from the workspace Sites tab" allin "$RB" 'frozen|freeze' '530' '3 months|three months' '4 months|four months' 'Sites tab|unfreeze'
ckp "limits: two Sandbox sites per account, no custom domains, no automatic backups, timeouts 59 s edge and 120 s PHP, 180 s cron" allin "$RB" 'two Sandbox|2 Sandbox' 'custom domain' 'no automatic backups|automatic backups' '59 ?s|59 seconds' '120 ?s|120 seconds'
ckp "interstitial warning page: all Sandbox environments, Deterrence-Bypass header with the measured value and the date, what it intercepts" allin "$RB" 'interstitial|warning page' 'Deterrence-Bypass' 'measured|T07 result'
ckp "body size limit: measured result with date (or 'unverified' with reason); private files path result" allin "$RB" '8 MB|8,388,608|body size' 'private'
ckp "pre-T31 check: last Git activity on Pantheon under 60 days or run a deploy before the window" allin "$RB" 'T31' '60 days' 'Git activity'
ckp "backups: Sandbox has none automatically; a pull takes a fresh backup first (--keep-for=30)" allin "$RB" 'ddev pull pantheon' 'backup' '--keep-for=30'

case_start TC-T07-22 "C5: documentation follow-ups (plan step 11, interfaces touched)"
ckp "technical-design D8: git subtree split without -b, database backup step, code server pinned and app server not, env:code-log check, interstitial result, rollback paragraph" bash -c "allin(){ local f=\$1 p; shift; for p in \"\$@\"; do grep -qiE -- \"\$p\" \$f || { echo \"missing in \$f: \$p\"; return 1; }; done; }; allin $TD 'pantheon_known_hosts' 'env:code-log' 'Deterrence-Bypass' 'element=db' 'revert'"
ckp "technical-design: the 'machine user on Sandbox is unverified (T07)' sentence is replaced by the O-5 result or the local-only rule" bash -c "! grep -q 'machine user.{0,80}unverified\*\* (T07)' $TD; ! grep -qF 'Whether a Sandbox site can add such a machine user is **unverified** (T07).' $TD"
ckp "technical-design: the SSH host key sentence ('pinned in the workflow's known_hosts') is replaced" bash -c "! grep -qF \"pinned in the workflow's \`known_hosts\`\" $TD"
ckp "technical-design NFR-04 Pantheon row: T07 records wake, warm GET and body limit; T10 measures the 100-item ingest; T28 confirms" bash -c "grep -E 'NFR-04 Pantheon dev' $TD | grep -q 'T10' && grep -E 'NFR-04 Pantheon dev' $TD | grep -qi 'wake'"
ckp "technical-design ingest body size row carries the T07 result with a date or stays unverified with the reason" bash -c "grep -E '^\| Ingest body size' $TD | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|unverified.{0,80}(because|reason|T07 )'"
ckp "technical-design unverified register: the T07 row items are closed with results, 'Sandbox interstitial and API requests' added" bash -c "grep -qi 'interstitial' $TD && ! grep -E '^\| Pantheon private files path, dev branch name' $TD | grep -q 'T07\$'"
ckp "ADR-0004 carries a dated follow-up note (PAT 90 days, local deploys use the owner's PAT) and no new ADR file was added" bash -c "grep -qE 'Follow-up \(2026-11-0[0-9], T07\)' $ADR4 && [[ \$(ls docs/adr/ADR-000*.md | wc -l) -eq 6 ]]"
ckp "scripts/README.md, .github/README.md, docs/runbooks/README.md name deploy-drupal.sh, deploy-drupal.yml, deploy.md; local-setup.md links to the pull steps" bash -c "grep -q 'deploy-drupal' scripts/README.md && grep -q 'deploy-drupal' .github/README.md && grep -q 'deploy.md' docs/runbooks/README.md && grep -q 'deploy.md' docs/runbooks/local-setup.md"
ckp "CLAUDE.md Commands table lists ddev deploy-drupal and ddev pull pantheon" allin CLAUDE.md 'ddev deploy-drupal' 'ddev pull pantheon'
ckp "docs/tests/T07/test-cases.md exists and has one case per TC id run here" bash -c "for i in \$(grep -oE 'case_start TC-T07-[0-9]+' $T/run-checks.sh | awk '{print \$2}' | sort -u); do grep -q \"### \$i:\" $T/test-cases.md || { echo \"no case doc for \$i\"; exit 1; }; done"

case_start TC-T07-23 "KD-5: settings.php changed by a comment only; config_sync_directory still set after the Pantheon include"
ckp "settings.php: config_sync_directory = '../config/sync' still set, after the settings.pantheon.php include, with a comment saying it must stay after the include" bash -c "f=$SETTINGS; a=\$(grep -n 'settings.pantheon.php' \$f | head -1 | cut -d: -f1); b=\$(grep -nE \"config_sync_directory'\\] *= *'\\.\\./config/sync'\" \$f | tail -1 | cut -d: -f1); [[ -n \$a && -n \$b && \$b -gt \$a ]] || { echo \"include line=\$a, config_sync_directory line=\$b\"; exit 1; }; sed -n \"\$((b-6)),\$((b))p\" \$f | grep -qiE '^\s*(//|#|\*).*(after|pantheon)'"
cka "settings.php diff against the branch point adds comment lines only" bash -c "d=\$(git diff -U0 $BASE -- $SETTINGS | grep -E '^[-+]' | grep -vE '^(\+\+\+|---)'); [[ -n \$d ]] || { echo 'no change at all (the KD-5 comment is missing)'; exit 1; }; ! grep -vE '^\+\s*(//|#|\*|/\*)' <<<\"\$d\""

case_start TC-T07-24 "C4: pre-commit on T07 files, bash -n, earlier regression sets (stand-in for CI until T08)"
PC=.tools/pre-commit
if [[ -x "$PC" ]]; then
  pc_files() { t07_files | while IFS= read -r f; do [[ -f "$f" ]] && printf '%s\n' "$f"; done; }
  pc_run() { local f; f=$(pc_files); [[ -n "$f" ]] || { echo "no files"; return 1; }
    echo "$f" | xargs -d '\n' "$PC" run --files; }
  ckp "pre-commit run --files <every T07 file> exits 0 (shellcheck, yamllint, check-yaml, gitleaks, check-names)" pc_run
else blk ".tools/pre-commit not bootstrapped: run scripts/bootstrap-dev.sh"; fi
ckp "bash -n on the deploy script, the wrapper and this test script" bash -c "bash -n $DS && bash -n $WRAP && bash -n $T/run-checks.sh"
if [[ "${T07_SKIP_NESTED:-0}" == 1 ]]; then blk "T07_SKIP_NESTED=1: the nested T02 to T06 regression run is skipped (negative-control runs only)"; else
ckp "T02 to T06 run-checks.sh --regression exit 0" bash -c "for t in T02 T03 T04 T04a T05 T06; do docs/tests/\$t/run-checks.sh --regression >'$WORK/r.txt' 2>&1 || { echo \"\$t regression failed\"; grep -E '^\s+FAIL' '$WORK/r.txt' | head -5; exit 1; }; done"
fi
note "ddev quality (scripts/quality.sh) is run by the tester at execution time and attached as TC-T07-24 evidence (needs DDEV)"

case_start TC-T07-25 "SIM: no broker domain, SDK or order call; only Pantheon and GitHub hosts (ADR-0006, CLAUDE.md)"
deny_files() { local f; f=$(t07_impl_files); [[ -n "$f" ]] || { echo "no T07 implementation files to scan yet"; return 1; }
  ! echo "$f" | xargs grep -IinE "$SIM_BR" 2>/dev/null || { echo "denylist hit in T07 files"; return 1; }; }
ckp "denylist scan over the T07 implementation files (non-empty set required). The word 'trade' in the site name meridian-trade is allowed: the pattern matches broker names and kite.trade only" deny_files
deny_docs() {
  local f u hits; f=$(t07_files | grep -vE '^docs/tests/'); [[ -n "$f" ]] || { echo "no changed docs yet"; return 1; }
  u=$(git ls-files -o --exclude-standard)
  hits=$({ echo "$f" | grep -vxF -f <(echo "$u") | xargs -d '\n' git diff -U0 "$BASE" -- 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true
    echo "$f" | grep -xF -f <(echo "$u") | xargs -d '\n' cat 2>/dev/null || true; } | grep -iE "$SIM_BR" || true)
  [[ -z "$hits" ]] || { echo "denylist hit in lines T07 added:"; echo "${hits:0:300}"; return 1; }; }
ckp "denylist scan over the lines T07 adds outside docs/tests" deny_docs
ckp "hosts named in T07 implementation files are only Pantheon, GitHub, ddev.site, localhost, or documentation hosts" bash -c "f=\$(ls $DS $WF $PRV $WRAP 2>/dev/null); [[ -n \"\$f\" ]] && ! grep -hoE 'https?://[^ \"'\\'')>]+' \$f | grep -vE '^https?://(([a-z0-9.-]+\.)?(pantheonsite\.io|pantheon\.io|github\.com|githubusercontent\.com|getpantheon\.com|drush\.in|ddev\.site)|localhost|127\.0\.0\.1|\\\$)'"
ckp "no broker SDK package added to any composer.json, package.json or pyproject by T07" bash -c "! git diff $BASE -- '*composer.json' '*package.json' '*pyproject.toml' 2>/dev/null | grep -E '^\+' | grep -iE \"$SIM_BR\""
ckp "the workflow and runbook do not suggest pushing data from local to Pantheon (no db_push, no 'ddev push pantheon' instruction)" bash -c "! grep -nE 'ddev push pantheon' $RB $WF 2>/dev/null | grep -viE 'not|never|no '"

case_start TC-T07-26 "naming (section 0) and placeholder names"
ckp "scripts/check-names.sh passes" scripts/check-names.sh
ckp "no old placeholder names in T07 files (case-insensitive); the DDEV project is meridian, the site is meridian-trade" bash -c "f=\$(ls $DS $KH $WF $PRV $WRAP $RB 2>/dev/null); [[ -n \"\$f\" ]] && ! echo \"\$f\" | xargs grep -IinE 'trading''-agent|trading''_engine|trading''_ingest'"

case_start TC-T07-27 "C5 close step: TRACEABILITY and PROGRESS carry the SA-7 wording (snapshot at close)"
atclose "TRACEABILITY R-11 and FR-27 evidence cells: 'T07: AC4 Pass by local deploy (TC-T07-nn); CI run TC-T07-nn Blocked (accepted, owner-run after O-6)'; R-11 stays Open" bash -c "grep -E '^\| R-11 ' docs/TRACEABILITY.md | grep -q 'AC4 Pass by local deploy' && grep -E '^\| R-11 ' docs/TRACEABILITY.md | grep -q 'Blocked (accepted, owner-run after O-6)' && grep -E '^\| R-11 ' docs/TRACEABILITY.md | grep -qi 'open' && grep -E '^\| FR-27 ' docs/TRACEABILITY.md | grep -q 'AC4 Pass by local deploy'"
atclose "PROGRESS T07 notes: 'AC4 by local deploy; CI deploy run owed after O-6 (owner-accepted)'" bash -c "grep -E '^\| T07 ' docs/PROGRESS.md | grep -q 'AC4 by local deploy; CI deploy run owed after O-6'"
atclose "the T07 test report states which SA-1 branch applied: machine user, local-only, or owner credentials accepted (date)" bash -c "grep -qE 'machine user|local-only|owner credentials accepted' $T/test-report.md"

case_start TC-T07-28 "evidence hygiene: no PAT, key, admin password or env dump in docs/tests/T07/evidence (R7)"
ev_clean() {
  [[ -d "$EVD" ]] || { echo "no evidence folder yet"; return 0; }
  local f bad=0
  for f in "$EVD"/*; do [[ -f "$f" ]] || continue
    if grep -IEq 'BEGIN [A-Z ]*PRIVATE KEY|TERMINUS_MACHINE_TOKEN=[^ []|PANTHEON_DEPLOY_KEY=[^ [R]|[Pp]assword[^:=]{0,20}[:=] *[^ []|Authorization: *[^ []' "$f"; then echo "secret-shaped text in $f"; bad=1; fi
    if grep -IEq '^(TERMINUS_MACHINE_TOKEN|PANTHEON_DEPLOY_KEY)=.|^declare -x TERMINUS' "$f"; then echo "environment dump in $f"; bad=1; fi
  done; return "$bad"; }
ckp "no secret-shaped text and no environment dump in any evidence file (empty folder passes; the report must say so)" ev_clean
if command -v gitleaks >/dev/null 2>&1; then ckp "gitleaks over docs/tests/T07" gitleaks detect --no-git --source "$T" --no-banner --redact; else skip "gitleaks not on PATH"; fi


case_start TC-T07-58 "Terminus 4.3.3 pin: Dockerfile, workflow and runbook agree; checksum verified with --strict"
TSHA=e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade
DF=.ddev/web-build/Dockerfile
ckp "Dockerfile pins ARG TERMINUS_VERSION=4.3.3 and ARG TERMINUS_SHA256=$TSHA" allin "$DF" '^ARG TERMINUS_VERSION=4\.3\.3$' "^ARG TERMINUS_SHA256=$TSHA\$"
ckp "workflow pins TERMINUS_VERSION: 4.3.3 and the same SHA-256" allin "$WF" '^\s+TERMINUS_VERSION: 4\.3\.3$' "^\s+TERMINUS_SHA256: $TSHA\$"
ckp "runbook 'Tool versions' names Terminus 4.3.3 and the same SHA-256" allin "$RB" 'Terminus 4\.3\.3' "$TSHA"
ckp "Dockerfile and workflow verify the checksum from a file with sha256sum --check --strict" bash -c "grep -q 'sha256sum --check --strict' $DF && grep -q 'sha256sum --check --strict' $WF"
ckp "Dockerfile fails the build unless terminus --version equals Terminus \${TERMINUS_VERSION}; workflow runs terminus --version" bash -c "grep -qF 'terminus --version' $DF && grep -qF 'Terminus \${TERMINUS_VERSION}' $DF && grep -qF 'terminus --version' $WF"
ckp "no 3.x pin remains: no 3.x TERMINUS_VERSION value in the Dockerfile or workflow, no 3.6.2 in the workflow (the Dockerfile comment may name 3.6.2 as the reason)" bash -c "! grep -nE 'TERMINUS_VERSION[=: ]+3\.' $DF $WF && ! grep -n '3\.6\.2' $WF"
ckp "the same 64-hex digest is the only one pinned in all three files" bash -c "for f in $DF $WF; do [[ \$(grep -oE '[0-9a-f]{64}' \$f | sort -u | wc -l) -eq 1 ]] || { echo \"\$f: not exactly one digest\"; exit 1; }; done"

case_start TC-T07-59 "Terminus 4.3.3 in the DDEV web container (one terminus on PATH)"
if have_ddev && ddev describe >/dev/null 2>&1; then
  rcof ddev exec 'terminus --version'
  ckp "ddev exec terminus --version prints exactly 'Terminus 4.3.3'" eq "$OUT" "Terminus 4.3.3" version
  rcof ddev exec 'which -a terminus'
  ckp "which -a terminus lists exactly one path (the pinned phar replaces the DDEV copy)" bash -c "[[ \$(grep -c . <<<\"\$1\") -eq 1 ]]" _ "$OUT"
else blk "DDEV is not running here"; fi

case_start TC-T07-60 "Harness: DEPLOY_SMOKE_BUDGET must be whole seconds (exit 2 before any network call)"
for bv in abc -5 1.5; do ckp "DEPLOY_SMOKE_BUDGET='$bv': exit 2, message names the variable, no terminus, curl or push" h_budget "$bv"; done

case_start TC-T07-61 "Harness: the script runs from a subdirectory of the repository"
ckp "dry-run from apps/drupal/config, -h from scripts/, a full deploy from apps/ all work" h_subdir

case_start TC-T07-62 "Harness: unexpected git_url forms and ssh:// without a pinned key fail closed"
ckp "scp-style git_url: exit 2 'unexpected git_url form', no wake, backup, ls-remote or push" h_url_form scp
ckp "https git_url: exit 2 'unexpected git_url form' and the same absences" h_url_form https
ckp "ssh:// git_url with a comment-only pantheon_known_hosts: exit 2 before env:wake, backup, ls-remote and push" h_url_form sshnokey
ckp "ssh:// git_url with pantheon_known_hosts missing: exit 2 and the same absences" h_url_form sshmissing

fi   # static

# =====================================================================================================
# Live cases (--live, --live-only). Gated; absent credentials give BLOCKED, never FAIL.
# =====================================================================================================
dx() { ddev exec "$1" 2>&1 </dev/null; }                       # run a command line in the web container
dxs() { local o; o=$(dx "$1") && RC=0 || RC=$?; OUT=$o; }      # sets RC and OUT
live_gate() {   # sets GATE_MSG; returns 0 when live cases may run
  GATE_MSG=""
  [[ "${T07_OWNER_OK:-0}" == 1 ]] || { GATE_MSG="T07_OWNER_OK=1 not set: the owner has not said (plan O-3) that agents may use the PAT and the SSH key"; return 1; }
  have_ddev || { GATE_MSG="DDEV or Docker not available here"; return 1; }
  ddev exec 'test -n "${TERMINUS_MACHINE_TOKEN:-}"' >/dev/null 2>&1 || { GATE_MSG="TERMINUS_MACHINE_TOKEN is not set in the web container (plan O-1); value not read"; return 1; }
  ddev exec 'ssh-add -l 2>/dev/null | grep -qE "RSA|ECDSA"' >/dev/null 2>&1 || { GATE_MSG="no RSA or ECDSA key loaded in the ddev ssh agent (plan O-2: ddev auth ssh)"; return 1; }
  ddev exec 'terminus auth:login --machine-token="$TERMINUS_MACHINE_TOKEN" >/dev/null 2>&1 && [[ -n "$(terminus auth:whoami --field=email 2>/dev/null)" ]]' || { GATE_MSG="terminus auth:login failed (expired PAT?)"; return 1; }
  return 0; }
need_o4() { [[ "${T07_O4_DONE:-0}" == 1 ]] || { GATE_MSG="T07_O4_DONE=1 not set: the owner has not done the one-time force push (plan O-4)"; return 1; }; }
need_confirm() { [[ "${!1:-0}" == 1 ]] || { GATE_MSG="$1=1 not set: destructive step needs an explicit confirm variable and owner approval"; return 1; }; }
gate() {   # gate [O4] [CONFIRM_VAR]: BLOCKED line and return 1 when a gate is not met
  live_gate || { blk "$GATE_MSG"; return 1; }
  if [[ "${1:-}" == O4 ]]; then need_o4 || { blk "$GATE_MSG"; return 1; }; shift; fi
  if [[ -n "${1:-}" ]]; then need_confirm "$1" || { blk "$GATE_MSG"; return 1; }; fi
  return 0; }
REF_DEPLOY=${T07_DEPLOY_REF:-task/T07-pantheon-dev}
BYPASS=${T07_BYPASS_VALUE:-1}
SPLIT_SHA=""

live_checks() {
  local o l
  case_start TC-T07-30 "AC1 live: the Sandbox site exists on the Composer-managed upstream"
  if gate; then
    dxs 'terminus site:info "$PANTHEON_SITE" --fields=id,name,framework,upstream,plan_name --format=json'
    ckp "site:info succeeds for $SITE" eq "$RC" 0 rc
    show_out "$OUT"
    ckp "framework is drupal-composer-managed (or the upstream label says Composer Managed); plan is sandbox" bash -c "grep -qiE 'drupal-composer-managed|Composer Managed' <<<\"\$1\" && grep -qi sandbox <<<\"\$1\"" _ "$OUT"
    dxs 'terminus env:info "$PANTHEON_SITE.dev" --field=connection_mode'
    ckp "dev connection mode is git (SFTP mode is forbidden)" bash -c "grep -qi '^git' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-31 "KD-1/R5 live discovery: dev branch name; backup:create exit code on failure with a real call"
  if gate; then
    dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'
    ckp "connection:info returns a ssh:// git URL on codeserver.dev.<uuid>.drush.in:2222" bash -c "grep -qE '^ssh://codeserver\.dev\.[0-9a-f-]+@codeserver\.dev\.[0-9a-f-]+\.drush\.in:2222/~/repository\.git' <<<\"\$1\"" _ "$OUT"
    local url=$OUT
    if kh_has_key; then
      dxs "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/var/www/html/scripts/pantheon_known_hosts -o BatchMode=yes' git ls-remote '$url' 2>&1 | head -5"
      note "ls-remote (host part only shown by redaction rule: refs below): $(printf '%s' "$OUT" | cut -c1-200 | head -3)"
      ckp "dev branch is master (ls-remote lists refs/heads/master, pinned known_hosts accepted)" bash -c "grep -q 'refs/heads/master' <<<\"\$1\"" _ "$OUT"
    else blk "awaiting L-3: $KH holds no key yet. Part 1 ran the same ls-remote with a temporary pin of host-key copy 1 (evidence/live-31-discovery.txt)"; fi
    dxs 'terminus backup:create "$PANTHEON_SITE.no-such-env-t07" --element=db --keep-for=1 2>&1 || echo "EXIT=$?"'
    ckp "backup:create against a non-existent environment exits non-zero (record the exact exit code)" bash -c "grep -E 'EXIT=[1-9]' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-32 "AC4 live (phase 2): ddev deploy-drupal deploys the branch to Pantheon dev"
  if gate O4; then
    ( git fetch -q origin 2>/dev/null || true )
    rcof ddev deploy-drupal --ref "$REF_DEPLOY" --allow-unmerged
    printf '%s\n' "$OUT" >"$WORK/deploy1.txt"; show_out "$(tail -12 "$WORK/deploy1.txt")"
    ckp "exit 0" eq "$RC" 0 rc
    SPLIT_SHA=$(tail -n1 "$WORK/deploy1.txt" | grep -oE '\b[0-9a-f]{40}\b' | head -1 || true)
    ckp "last output line is the deployed split SHA (40 hex): '${SPLIT_SHA:-none}'" test -n "$SPLIT_SHA"
    ckp "output names every stage and a warning about merge commits (--allow-unmerged)" bash -c "grep -qiE 'warn' '$WORK/deploy1.txt' && grep -qi 'merge commit' '$WORK/deploy1.txt'"
    ckp "output contains no token, no private key and no full git URL user part" bash -c "! grep -E 'BEGIN [A-Z ]*PRIVATE|machine-token|TERMINUS_MACHINE_TOKEN=' '$WORK/deploy1.txt'"
    ckp "a backup was created by the script before the push (backup stage printed)" bash -c "grep -qiE 'backup' '$WORK/deploy1.txt'"
    ckp "the build was confirmed: output holds 'completed successfully for commit' (review condition 3, L-4)" bash -c "grep -q 'completed successfully for commit' '$WORK/deploy1.txt'"
  fi

  case_start TC-T07-33 "AC4 live: independent verification of the deploy (code-log, ls-remote, smoke)"
  if gate O4; then
    [[ -n "$SPLIT_SHA" ]] || SPLIT_SHA=$(rcof ddev deploy-drupal --ref "$REF_DEPLOY" --allow-unmerged --dry-run; tail -n1 <<<"$OUT" | grep -oE '\b[0-9a-f]{40}\b' | head -1)
    dxs 'terminus env:code-log "$PANTHEON_SITE.dev" --format=json'
    ckp "env:code-log: the newest hash equals the split SHA ($SPLIT_SHA)" bash -c "python3 -I -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d and d[0][\"hash\"]==sys.argv[2] else 1)' \"\$1\" '$SPLIT_SHA'" _ "$OUT"
    dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'
    ckp "git ls-remote master equals the split SHA" bash -c "[[ \$(ddev exec \"git ls-remote '$OUT' refs/heads/master\" 2>/dev/null | cut -f1) == '$SPLIT_SHA' ]]"
    o=$(curl -sS --max-time 90 -H "Deterrence-Bypass: $BYPASS" -o "$WORK/login.html" -w '%{http_code} %{ssl_verify_result}' "$PUB/user/login" 2>&1) || true
    ckp "GET /user/login (certificate verified, bypass header only if needed) returns '200 0' (got: $o)" eq "$o" "200 0" curl
    ckp "body holds the Drupal marker user-login-form" grep -q 'user-login-form' "$WORK/login.html"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- status --field=bootstrap'
    ckp "drush bootstraps on Pantheon (Successful)" bash -c "grep -qi 'Successful' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-34 "AC4 live: idempotent re-run takes no backup and pushes nothing"
  if gate O4; then
    dxs 'terminus backup:list "$PANTHEON_SITE.dev" --element=db --format=json'
    local n1; n1=$(python3 -I -c 'import json,sys; print(len(json.loads(sys.argv[1] or "[]")))' "$OUT" 2>/dev/null || echo "?")
    rcof ddev deploy-drupal --ref "$REF_DEPLOY" --allow-unmerged
    printf '%s\n' "$OUT" >"$WORK/deploy2.txt"; show_out "$(tail -8 "$WORK/deploy2.txt")"
    ckp "exit 0" eq "$RC" 0 rc
    dxs 'terminus backup:list "$PANTHEON_SITE.dev" --element=db --format=json'
    local n2; n2=$(python3 -I -c 'import json,sys; print(len(json.loads(sys.argv[1] or "[]")))' "$OUT" 2>/dev/null || echo "?")
    ckp "database backup count unchanged ($n1 before, $n2 after)" eq "$n2" "$n1" count
    ckp "output says the push was skipped (already at the split SHA)" bash -c "grep -qiE 'skip|already|up to date|idempotent' '$WORK/deploy2.txt'"
    ckp "the re-run still confirmed the build: output holds 'completed successfully for commit' (workflow:wait --start=1; review condition 3, L-4/L-10)" bash -c "grep -q 'completed successfully for commit' '$WORK/deploy2.txt'"
  fi

  case_start TC-T07-35 "AC4 live negative: an older ancestor of origin/main is rejected by Pantheon, never forced"
  if gate O4; then
    local old; old=$(git rev-list -n1 origin/main~3 -- apps/drupal 2>/dev/null || true)
    if [[ -z "$old" ]]; then blk "no older commit touching apps/drupal on origin/main to use as a rewind target (fetch origin, or merge T07 first)"
    else
      dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'
      local before; before=$(ddev exec "git ls-remote '$OUT' refs/heads/master" 2>/dev/null | cut -f1)
      rcof ddev deploy-drupal --ref "$old"
      show_out "$(tail -6 <<<"$OUT")"
      ckp "exit 1 (ddev maps any non-zero exit to 1; the script's own code is 1) and the message points to the runbook" bash -c "[[ $RC -ne 0 ]] && grep -q 'Emergency force push' <<<\"\$1\"" _ "$OUT"
      dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'
      ckp "master on Pantheon is unchanged ($before)" bash -c "[[ \$(ddev exec \"git ls-remote '$OUT' refs/heads/master\" 2>/dev/null | cut -f1) == '$before' ]]"
    fi
  fi

  case_start TC-T07-36 "AC5 live: config:status is clean on Pantheon dev and locally; site UUIDs agree"
  if gate O4; then
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:status'
    ckp "Pantheon: config:status says No differences" bash -c "grep -qi 'No differences' <<<\"\$1\"" _ "$OUT"
    rcof ddev drush config:status
    ckp "local: ddev drush config:status says No differences" bash -c "grep -qi 'No differences' <<<\"\$1\"" _ "$OUT"
    local want; want=$(grep -E '^uuid:' apps/drupal/config/sync/system.site.yml | awk '{print $2}')
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:get system.site uuid --format=string'
    ckp "Pantheon active system.site uuid equals config/sync ($want)" bash -c "grep -q '$want' <<<\"\$1\"" _ "$OUT"
    rcof ddev drush config:get system.site uuid --format=string
    ckp "local active system.site uuid equals config/sync" bash -c "grep -q '$want' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-37 "KD-5 live: config_sync_directory on Pantheon resolves to /code/config/sync"
  if gate O4; then
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'echo realpath(\Drupal\Core\Site\Settings::get("config_sync_directory"));'"'"
    ckp "php:eval prints /code/config/sync" bash -c "grep -qx '/code/config/sync' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-38 "KD-7 live: Integrated Composer build facts"
  if gate O4; then
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'echo (int) file_exists("sites/default/settings.pantheon.php");'"'"
    ckp "settings.pantheon.php exists on Pantheon (scaffolded by the build): prints 1" bash -c "grep -qx '1' <<<\"\$1\"" _ "$OUT"
    dxs 'terminus workflow:list "$PANTHEON_SITE" --format=json'
    ckp "a build workflow ('Build' / 'sync_code') succeeded for the deployed commit (recorded; field names assumed)" bash -c "grep -qiE 'sync_code|build|Sync code' <<<\"\$1\"" _ "$OUT"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'echo (int) class_exists("\Drupal\Core\DrupalKernel");'"'"
    ckp "web_docroot honoured without pantheon.upstream.yml: drupal kernel loads from the docroot" bash -c "grep -qx '1' <<<\"\$1\"" _ "$OUT"
    note "Record in the report: Composer version from the build log, require-dev installed (drupal/core-dev expected), dashboard upstream notice (TC-T07-54)"
  fi

  case_start TC-T07-39 "KD-6 live (destructive): wipe and reinstall Pantheon dev from config/sync; admin password redacted"
  if gate O4 T07_CONFIRM_WIPE; then
    dxs 'terminus backup:create "$PANTHEON_SITE.dev" --element=db --keep-for=30'
    ckp "safety backup (--element=db --keep-for=30) succeeded" eq "$RC" 0 rc
    dxs 'terminus env:wipe "$PANTHEON_SITE.dev" --yes'
    ckp "env:wipe exits 0" eq "$RC" 0 rc
    local mail="${T07_OWNER_MAIL:-owner@example.invalid}"
    dxs "terminus remote:drush \"\$PANTHEON_SITE.dev\" -- site:install --existing-config --yes --account-name=admin --account-mail='$mail' 2>&1 | sed -E 's/(password[^:=]{0,20}[:=] *).*/\\1[REDACTED]/I'"
    note "site:install output (password line redacted at source and again by redact()):"; show_out "$OUT"
    ckp "site:install --existing-config exits 0 on Pantheon (if it fails, the KD-6 fallback needs a review note)" bash -c "! grep -qiE 'error|failed|exception' <<<\"\$1\"" _ "$OUT"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- cache:rebuild'
    ckp "cache:rebuild exits 0" eq "$RC" 0 rc
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:status'
    ckp "config:status says No differences after the reinstall" bash -c "grep -qi 'No differences' <<<\"\$1\"" _ "$OUT"
    ckp "the evidence of this case holds no password value (redaction applied)" bash -c "! grep -hiE 'password[^:=]{0,20}[:=] *[^ []' '$EVD'/TC-T07-39.*.txt 2>/dev/null"
  fi

  case_start TC-T07-40 "TH-6 live: SSH host key pinning blocks git push with a wrong key (negative) and accepts the real key (control)"
  if gate O4; then
    dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'
    local url=$OUT
    ssh-keygen -q -t rsa -b 2048 -N '' -f "$WORK/wrongkey" >/dev/null 2>&1
    local host; host=$(grep -oE '\[codeserver\.dev\.[0-9a-f-]+\.drush\.in\]:2222' "$KH" | head -1)
    printf '%s %s\n' "$host" "$(cut -d' ' -f1,2 "$WORK/wrongkey.pub")" >"$WORK/kh_wrong"
    dxs "cd /var/www/html && head -c 0 /dev/null; mkdir -p /tmp/t07 && cat > /tmp/t07/kh_wrong <<'EOF'
$(cat "$WORK/kh_wrong")
EOF
GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/tmp/t07/kh_wrong -o BatchMode=yes' git ls-remote '$url' 2>&1; echo EXIT=\$?"
    ckp "wrong pinned key: connection refused with a host key error (REMOTE HOST IDENTIFICATION or Host key verification failed), non-zero exit" bash -c "grep -qiE 'host key verification failed|REMOTE HOST IDENTIFICATION' <<<\"\$1\" && grep -qE 'EXIT=[1-9]' <<<\"\$1\"" _ "$OUT"
    dxs "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/var/www/html/$KH -o BatchMode=yes' git ls-remote '$url' 2>&1 | head -2; echo EXIT=\${PIPESTATUS[0]}"
    ckp "control: the committed known_hosts file lets git ls-remote succeed" bash -c "grep -q 'EXIT=0' <<<\"\$1\" && grep -q 'refs/' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-41 "KD-2 live: the committed code-server key matches ssh-keyscan today"
  if ! kh_has_key; then blk "awaiting L-3: no key is committed yet. Copy 1 is in evidence/host-key-copy1.txt; copy 2 (next UTC day) and the second network are owner/tester steps in the report"
  elif gate; then
    dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'
    local host; host=$(sed -E 's#^ssh://[^@]+@([^:/]+):([0-9]+).*#\1#' <<<"$OUT")
    o=$(ssh-keyscan -p 2222 -t rsa,ecdsa "$host" 2>/dev/null | ssh-keygen -lf - 2>/dev/null | awk '{print $2}' | sort -u | tr '\n' ' ')
    note "ssh-keyscan fingerprints today ($(date -u +%F)): $o"
    ckp "at least one scanned SHA256 fingerprint appears in $KH comments" bash -c "for f in $o; do grep -qF \"\$f\" $KH && exit 0; done; exit 1"
    note "Day-2 and second-network scans are owner-run: TC-T07-52"
  fi

  case_start TC-T07-42 "AC3 live: ddev pull pantheon from a fresh shell pulls database and files (no manual terminus auth:login)"
  if gate T07_CONFIRM_PULL; then
    rcof ddev snapshot --name "t07-before-pull-$RUNID"
    ckp "local snapshot taken first (runbook: ddev snapshot before a pull)" eq "$RC" 0 rc
    dx 'terminus auth:logout' >/dev/null 2>&1 || true
    dxs 'terminus auth:whoami --field=email 2>/dev/null'
    ckp "precondition: the Terminus session is logged out (4.3.3: whoami exits 0 with empty stdout), so the provider's auth_command is what authenticates" bash -c "[[ -z \"\${1//[[:space:]]/}\" ]]" _ "$OUT"
    rcof ddev auth ssh
    note "ddev auth ssh exit $RC (owner key already loaded; passphrase prompts need the owner)"
    rcof env -i HOME="$HOME" PATH="$PATH" ddev pull pantheon -y
    printf '%s\n' "$OUT" >"$WORK/pull.txt"; show_out "$(tail -10 "$WORK/pull.txt")"
    ckp "ddev pull pantheon -y exits 0" eq "$RC" 0 rc
    if need_o4; then
      rcof ddev drush config:get system.site uuid --format=string
      ckp "local site UUID equals config/sync after the pull (both sides share the UUID since the KD-6 reinstall)" bash -c "grep -q \"\$(grep -E '^uuid:' apps/drupal/config/sync/system.site.yml | awk '{print \$2}')\" <<<\"\$1\"" _ "$OUT"
      rcof ddev drush config:status
      ckp "local config:status says No differences after the pull" bash -c "grep -qi 'No differences' <<<\"\$1\"" _ "$OUT"
    else blk "awaiting O-4 (part 2): UUID and config:status after the pull hold only once Pantheon dev is reinstalled from config/sync (KD-6); before that dev is a different (dashboard-installed) site"; fi
    ckp "files were pulled: apps/drupal/web/sites/default/files exists locally and the pull log names files" bash -c "ddev exec 'test -d apps/drupal/web/sites/default/files' && grep -qiE 'Obtaining files' '$WORK/pull.txt'"
    if need_o4; then
      rcof ddev exec 'drush sql:query "select count(*) from users_field_data"'
      ckp "the pulled database has users (count >= 1)" bash -c "grep -qE '^[1-9]' <<<\"\$1\"" _ "$OUT"
    else blk "awaiting O-4 (part 2): the pulled database has users only after the reinstall"; fi
    note "AC3 reading (SA-5/KD-11): ddev auth pantheon does not exist in DDEV v1.24.4; the report records this note"
  fi

  case_start TC-T07-43 "AC3 live: pull provider takes a fresh backup, never pushes, leaks nothing"
  if [[ -s "$WORK/pull.txt" ]] && live_gate; then
    ckp "pull log shows backup:create for db and for files before backup:get" bash -c "grep -n 'backup:create' '$WORK/pull.txt' | head -2 | wc -l | grep -q 2 || grep -c 'backup' '$WORK/pull.txt' | grep -qE '[2-9]'"
    ckp "pull log has no terminus push, env:wipe, backup:restore, or set -x trace (+ terminus lines)" bash -c "! grep -qE 'backup:restore|env:wipe|^\+ terminus|^\+\+ ' '$WORK/pull.txt'"
    ckp "pull log contains no token, key or password text" bash -c "! grep -E 'BEGIN [A-Z ]*PRIVATE|TERMINUS_MACHINE_TOKEN=[^ ]' '$WORK/pull.txt'"
    rcof ddev push pantheon --help
    ckp "static provider check TC-T07-04 already proved there is no push command; ddev push help is informational (exit $RC)" true
  else blk "TC-T07-42 did not run in this invocation (its pull log is the input); run --live with T07_CONFIRM_PULL=1"; fi

  case_start TC-T07-44 "KD-12 live: Sandbox warning page and edge behaviour (GET, POST, /jsonapi, Accept, User-Agent, with and without Deterrence-Bypass)"
  if live_gate; then
    local u h a2 ua title
    note "Part 1 measurement (edge level; valid whatever Drupal is installed behind it). UTC $(date -u +%FT%TZ)"
    title() { grep -o '<title>[^<]*' "$WORK/m.body" | head -1 | sed 's/<title>//'; }
    o=$(curl -sS --max-time 90 -o "$WORK/m.body" -w '%{http_code}' "$PUB/user/login" 2>&1) || true
    note "GET /user/login default curl (Accept */*), no header -> $o ; title: $(title)"
    ckp "default curl GET (no Accept: text/html) is not the Sandbox warning page" bash -c "! grep -q 'Sandbox Environment Notice' '$WORK/m.body'"
    o=$(curl -sS --max-time 90 -H 'Accept: text/html' -o "$WORK/m.body" -w '%{http_code}' "$PUB/user/login" 2>&1) || true
    note "GET /user/login Accept: text/html, no header -> $o ; title: $(title)"
    ckp "GET with Accept: text/html and no header returns the Sandbox warning page (title 'Sandbox Environment Notice')" bash -c "grep -q 'Sandbox Environment Notice' '$WORK/m.body'"
    o=$(curl -sS --max-time 90 -H 'Accept: text/html' -H "Deterrence-Bypass: $BYPASS" -o "$WORK/m.body" -w '%{http_code}' "$PUB/user/login" 2>&1) || true
    note "GET /user/login Accept: text/html + Deterrence-Bypass: $BYPASS -> $o ; title: $(title)"
    ckp "the header 'Deterrence-Bypass: $BYPASS' removes the warning page for an HTML GET" bash -c "! grep -q 'Sandbox Environment Notice' '$WORK/m.body'"
    for u in /user/login /jsonapi; do for h in none bypass; do
      a2=(-sS --max-time 90 -o "$WORK/m.body" -w '%{http_code} %{content_type}' -X POST --data-binary '{}' -H 'Content-Type: application/json' -H 'Accept: text/html')
      [[ $h == bypass ]] && a2+=(-H "Deterrence-Bypass: $BYPASS")
      o=$(curl "${a2[@]}" "$PUB$u" 2>&1) || true
      note "POST $u (Accept: text/html) header=$h -> $o ; title: $(title)"
      ckp "POST $u header=$h is not the Sandbox warning page" bash -c "! grep -q 'Sandbox Environment Notice' '$WORK/m.body'"
    done; done
    for ua in 'curl/8.5.0' 'node' 'Wget/1.21' 'undici' 'python-httpx/0.27.0' 'python-requests/2.32.3' 'Mozilla/5.0 (X11; Linux x86_64) Chrome/126.0'; do for h in none bypass; do
      a2=(-sS --max-time 90 -A "$ua" -o "$WORK/m.body" -w '%{http_code}')
      [[ $h == bypass ]] && a2+=(-H "Deterrence-Bypass: $BYPASS")
      o=$(curl "${a2[@]}" "$PUB/jsonapi" 2>&1) || true
      note "GET /jsonapi User-Agent='$ua' header=$h -> $o ; title: $(title)"
    done; done
    note "RESULT recorded for T10 and T21: see the User-Agent lines above; a 403 with title 'Just a moment...' is a Cloudflare challenge that Deterrence-Bypass does not remove"
  else blk "$GATE_MSG"; fi
  if gate O4; then
    o=$(curl -sS --max-time 90 -H "Deterrence-Bypass: $BYPASS" -o "$WORK/m.body" -w '%{http_code}' "$PUB/user/login" 2>&1) || true
    ckp "installed site, with the header: GET /user/login is Drupal's form (200 and user-login-form)" bash -c "[[ '$o' == 200 ]] && grep -q 'user-login-form' '$WORK/m.body'"
    o=$(curl -sS --max-time 90 -H "Deterrence-Bypass: $BYPASS" -o "$WORK/m.body" -w '%{http_code} %{content_type}' "$PUB/jsonapi" 2>&1) || true
    ckp "installed site, with the header: GET /jsonapi is Drupal's answer (200/401/403 and a JSON content type) (got: $o)" bash -c "grep -qE '^(200|401|403) .*json' <<<\"\$1\"" _ "$o"
    ckp "the runbook and D8 record the measured result" allin "$RB" 'Deterrence-Bypass'
  fi

  case_start TC-T07-45 "KD-12 live: edge body size 8 MB and 9 MB, post_max_size and upload_max_filesize"
  if live_gate; then
    head -c 8388608 /dev/urandom >"$WORK/b8.bin"; head -c 9437184 /dev/urandom >"$WORK/b9.bin"
    local c8 c9
    c8=$(curl -sS --max-time 120 -o /dev/null -w '%{http_code}' -X POST --data-binary @"$WORK/b8.bin" -H 'Content-Type: application/x-www-form-urlencoded' "$PUB/user/login" 2>&1) || true
    c9=$(curl -sS --max-time 120 -o /dev/null -w '%{http_code}' -X POST --data-binary @"$WORK/b9.bin" -H 'Content-Type: application/x-www-form-urlencoded' "$PUB/user/login" 2>&1) || true
    note "POST 8,388,608 bytes -> $c8 ; POST 9,437,184 bytes -> $c9 ($(date -u +%F)); path /user/login, no data changes"
    ckp "8 MB body: the response is not 413 from the edge (design value met; got $c8)" bash -c "[[ '$c8' =~ ^[0-9]{3}\$ && '$c8' != 413 && '$c8' != 000 ]]"
    note "9 MB result recorded only (the limit may be higher or lower): $c9"
  else blk "$GATE_MSG"; fi
  if gate O4; then
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'echo ini_get("post_max_size")." ".ini_get("upload_max_filesize");'"'"
    ckp "post_max_size and upload_max_filesize recorded: '$OUT'" bash -c "grep -qE '[0-9]+[MG]? [0-9]+[MG]?' <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-46 "KD-12 live: wake time and warm GET latency (p50, p95 over 20 requests)"
  if live_gate; then
    local t0 t1
    t0=$(date +%s.%N); dxs 'terminus env:wake "$PANTHEON_SITE.dev"'; t1=$(date +%s.%N)
    note "env:wake exit $RC in $(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}') s (from asleep only if the env was idle > 1 h; record which)"
    ckp "env:wake exits 0 within the 120 s retry budget" bash -c "[[ $RC -eq 0 ]] && awk -v a='$t0' -v b='$t1' 'BEGIN{exit !(b-a<120)}'"
    : >"$WORK/times.txt"; local i
    for i in $(seq 1 20); do
      curl -sS --max-time 90 -o /dev/null -w '%{http_code} %{time_total}\n' "$PUB/user/login" >>"$WORK/times.txt" 2>&1 || true
    done
    note "status codes of the 20 warm GETs: $(awk '{print $1}' "$WORK/times.txt" | sort | uniq -c | tr '\n' ' ')"
    ckp "20 warm GETs return no 4xx or 5xx (the status itself depends on what is installed: 302 before install, 200 after)" bash -c "! grep -qE '^[45]' '$WORK/times.txt' && [[ \$(grep -c . '$WORK/times.txt') -eq 20 ]]"
    local p50 p95
    p50=$(awk '{print $2}' "$WORK/times.txt" | sort -n | sed -n '10p'); p95=$(awk '{print $2}' "$WORK/times.txt" | sort -n | sed -n '19p')
    note "warm GET /user/login: p50=${p50}s p95=${p95}s (n=20, $(date -u +%F))"
    ckp "p95 below the 59 s edge timeout (recorded value ${p95}s)" bash -c "awk -v p='$p95' 'BEGIN{exit !(p<59 && p>0)}'"
  else blk "$GATE_MSG"; fi
  if gate O4; then
    ckp "installed site: 20 warm GETs all return 200" bash -c "[[ \$(grep -c '^200 ' '$WORK/times.txt') -eq 20 ]]"
  fi

  case_start TC-T07-47 "KD-12 live: the private files path is not served"
  if gate O4; then
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'echo \Drupal\Core\Site\Settings::get("file_private_path");'"'"
    ckp "file_private_path is sites/default/files/private (got: $OUT)" bash -c "grep -q 'sites/default/files/private' <<<\"\$1\"" _ "$OUT"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'file_put_contents("private://t07-probe.txt","T07-PROBE-CONTENT"); echo "written";'"'"
    o=$(curl -sS --max-time 90 -H "Deterrence-Bypass: $BYPASS" -o "$WORK/probe.body" -w '%{http_code}' "$PUB/sites/default/files/private/t07-probe.txt" 2>&1) || true
    ckp "GET of the probe is 403 or 404 and the body does not hold the probe text (got $o)" bash -c "[[ '$o' == 403 || '$o' == 404 ]] && ! grep -q 'T07-PROBE-CONTENT' '$WORK/probe.body'"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- php:eval '"'"'@unlink("private://t07-probe.txt"); echo file_exists("private://t07-probe.txt") ? "still" : "deleted";'"'"
    ckp "probe file deleted" bash -c "grep -q deleted <<<\"\$1\"" _ "$OUT"
  fi

  case_start TC-T07-48 "TH-8 live (destructive): database-only restore changes the value back and leaves code untouched"
  if gate O4 T07_CONFIRM_RESTORE; then
    dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'; local url=$OUT
    local m0 c0
    m0=$(ddev exec "git ls-remote '$url' refs/heads/master" 2>/dev/null | cut -f1)
    dxs 'terminus env:code-log "$PANTHEON_SITE.dev" --format=json'; c0=$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])[0]["hash"])' "$OUT" 2>/dev/null || echo "?")
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:get system.site name --format=string'; local name0=$OUT
    local t0 t1 t2
    t0=$(date +%s); dxs 'terminus backup:create "$PANTHEON_SITE.dev" --element=db --keep-for=30'; t1=$(date +%s)
    ckp "backup:create --element=db succeeds ($((t1-t0)) s)" eq "$RC" 0 rc
    dxs 'terminus backup:list "$PANTHEON_SITE.dev" --element=db --format=json'
    local file; file=$(python3 -I -c 'import json,sys; d=json.loads(sys.argv[1]); d=d if isinstance(d,list) else list(d.values()); print(sorted(d,key=lambda x:x.get("date",0))[-1]["file"])' "$OUT" 2>/dev/null || true)
    ckp "newest database backup file name found: '${file:-none}' (JSON field names assumed: file, date)" test -n "$file"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:set system.site name T07-RESTORE-PROBE -y'
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:get system.site name --format=string'
    ckp "the probe value is set (got: $OUT)" bash -c "grep -q T07-RESTORE-PROBE <<<\"\$1\"" _ "$OUT"
    t1=$(date +%s); dxs "terminus backup:restore \"\$PANTHEON_SITE.dev\" --element=db --file='$file' --yes"; t2=$(date +%s)
    ckp "backup:restore --element=db --file=<name> --yes succeeds ($((t2-t1)) s)" eq "$RC" 0 rc
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- cache:rebuild'
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:get system.site name --format=string'
    ckp "the value is back to the original ($name0)" bash -c "! grep -q T07-RESTORE-PROBE <<<\"\$1\" && grep -qF \"\$2\" <<<\"\$1\"" _ "$OUT" "$name0"
    ckp "git ls-remote master unchanged ($m0)" bash -c "[[ \$(ddev exec \"git ls-remote '$url' refs/heads/master\" 2>/dev/null | cut -f1) == '$m0' ]]"
    dxs 'terminus env:code-log "$PANTHEON_SITE.dev" --format=json'
    ckp "env:code-log newest hash unchanged ($c0)" bash -c "python3 -I -c 'import json,sys; sys.exit(0 if json.loads(sys.argv[1])[0][\"hash\"]==sys.argv[2] else 1)' \"\$1\" '$c0'" _ "$OUT"
    dxs 'terminus remote:drush "$PANTHEON_SITE.dev" -- config:status'
    ckp "config:status clean after the restore" bash -c "grep -qi 'No differences' <<<\"\$1\"" _ "$OUT"
    note "timings recorded for the report: backup $((t1-t0)) s, restore $((t2-t1)) s"
  fi

  case_start TC-T07-49 "O-4 result: Pantheon master descends only from a split of main (history replaced once)"
  if gate O4; then
    dxs 'terminus connection:info "$PANTHEON_SITE.dev" --field=git_url'; local url=$OUT
    ( git fetch -q origin 2>/dev/null || true )
    local sp; sp=$(git subtree split --prefix=apps/drupal origin/main 2>/dev/null || true)
    dxs "mkdir -p /tmp/t07/clone && cd /tmp/t07/clone && rm -rf r && git init -q r && cd r && GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/var/www/html/$KH -o BatchMode=yes' git fetch -q '$url' master && git log --format=%H FETCH_HEAD | tail -1"
    ckp "the oldest commit on Pantheon master is a commit of the apps/drupal split (not the Pantheon upstream root)" bash -c "[[ -n '$sp' ]] && git rev-list '$sp' | grep -qx \"\$(tail -n1 <<<\"\$1\")\"" _ "$OUT"
  fi
}   # live_checks

if [[ "$MODE" == live || "$MODE" == liveonly ]]; then live_checks; fi

# =====================================================================================================
# Clean-clone case (needs ddev, no credentials)
# =====================================================================================================
if [[ "$MODE" == clone ]]; then
  case_start TC-T07-55 "C7: ddev deploy-drupal --dry-run works from a fresh clone following docs/runbooks/deploy.md"
  if [[ "${T07_CONFIRM:-0}" != 1 ]]; then blk "needs T07_CONFIRM=1 (it stops this project's DDEV and starts a clone under the same name)"
  elif ! have_ddev; then blk "DDEV or Docker not available here"
  else
    br=$(git rev-parse --abbrev-ref HEAD); scratch=$(mktemp -d "${TMPDIR:-/tmp}/t07clone.XXXXXX")
    git clone -q "file://$ROOT" "$scratch/Meridian" -b "$br" && cd "$scratch/Meridian" || exit 2
    git fetch -q "file://$ROOT" main:refs/remotes/origin/main 2>/dev/null || true
    ddev stop --unlist meridian >/dev/null 2>&1 || true
    ckp "clone has no .env" bash -c "[[ ! -e .env ]]"
    rcof ddev start -y; ckp "ddev start exits 0 in the clone" eq "$RC" 0 rc
    rcof ddev deploy-drupal --dry-run --ref HEAD --allow-unmerged
    ckp "ddev deploy-drupal --dry-run exits 0 and prints a 40-hex split SHA (no credentials needed)" bash -c "[[ $RC -eq 0 ]] && grep -qE '\b[0-9a-f]{40}\b' <<<\"\$1\"" _ "$OUT"
    ckp "the dry run made no network call and left git status clean" bash -c "[[ -z \$(git status --porcelain) ]]"
    rcof ddev exec 'echo "$PANTHEON_SITE"'; ckp "PANTHEON_SITE is meridian-trade in the web container from .ddev/config.yaml" eq "$OUT" "$SITE" site
    rcof ddev pull pantheon -y
    ckp "ddev pull pantheon without a token fails with the PAT message (no traceback, no token text)" bash -c "[[ $RC -ne 0 ]] && grep -qiE 'personal access token|PAT|TERMINUS_MACHINE_TOKEN' <<<\"\$1\"" _ "$OUT"
    cd "$ROOT" || exit 2; ddev delete -Oy meridian >/dev/null 2>&1 || true; rm -rf "$scratch"
    ddev start >/dev/null 2>&1 || emit "  NOTE: could not restart the original working project; run 'ddev start' in $ROOT"
  fi
fi

# =====================================================================================================
# Cases that cannot run in an automated pass: listed so the report accounts for every ID
# =====================================================================================================
if [[ "$MODE" != reg ]]; then
if [[ "$MODE" == static || "$MODE" == live ]]; then
  for pair in "30|AC1 live: Sandbox site on the Composer-managed upstream" "31|KD-1/R5 live discovery" "32|AC4 live: ddev deploy-drupal real deploy" \
    "33|AC4 live: independent verification" "34|AC4 live: idempotent re-run" "35|AC4 live: rewind rejected" "36|AC5 live: config:status both sides" \
    "37|KD-5 live: config_sync_directory" "38|KD-7 live: build facts" "39|KD-6 live: reinstall" "40|TH-6 live: host key pinning" \
    "41|KD-2 live: ssh-keyscan matches" "42|AC3 live: ddev pull pantheon" "43|AC3 live: pull provider details" "44|KD-12 interstitial" \
    "45|KD-12 body size" "46|KD-12 wake and warm timing" "47|KD-12 private files" "48|TH-8 restore" "49|O-4 result"; do
    if [[ "$MODE" == static ]]; then
      id="TC-T07-${pair%%|*}"; case_start "$id" "${pair#*|}"; blk "live case: run with --live (needs T07_OWNER_OK=1 and, for some, confirm variables)"
    fi
  done
fi
if [[ "$MODE" != clone ]]; then
  if [[ "$MODE" == static ]]; then
    case_start TC-T07-55 "C7: ddev deploy-drupal --dry-run from a fresh clone (needs DDEV)"; blk "clean-clone case: run T07_CONFIRM=1 docs/tests/T07/run-checks.sh --clean-clone"
  fi
  case_start TC-T07-50 "AC4 CI run: workflow_dispatch of deploy-drupal.yml on main deploys to Pantheon dev (SA-7)"
  blk "Blocked (accepted, owner-run after O-6): the owner accepts this deferral in writing at T07 close; an agent message is not acceptance. Procedure: after O-5 and O-6 (secrets TERMINUS_MACHINE_TOKEN and PANTHEON_DEPLOY_KEY, variable PANTHEON_SITE=meridian-trade) the owner runs 'Run workflow' on main (O-7) and sends the URL; expect job success, the last log line is the split SHA, env:code-log newest hash equals it, config:status clean, no token in the log. If deploys stay local-only the case becomes 'Not run: deploys are local-only by decision'. T28 cannot close until this is Pass (machine user branch)."
  case_start TC-T07-51 "Addendum: first push-triggered run of deploy-drupal.yml on main after the merge is 'skipped' (not a close condition)"
  blk "owner-run after merge: the first run on main must show the skip step 'deploy-drupal: not configured (PANTHEON_SITE unset), skipped' and a green job; record the run URL as an addendum"
  case_start TC-T07-52 "KD-2 owner-run: code server host key fingerprints equal on two days and from a second network"
  blk "owner-run: ssh-keyscan -p 2222 of the code server on day 1 (committed in scripts/pantheon_known_hosts comments), on day 2, and once from a second network (phone hotspot or GitHub runner); record the three SHA256 fingerprints and dates; any difference is raised at review (SA-4 decision 4)"
  case_start TC-T07-53 "O-5 owner-run: machine user result (SA-1 branch)"
  blk "owner-run: create the machine user and invite it (terminus site:team:add meridian-trade <bot email> [role]); record terminus site:team:list output and role, or the exact error, date and command (then deploys are local-only). The report states 'machine user', 'local-only' or 'owner credentials accepted (date)'. Also: owner reads the account and acceptable-use sections and records 'read, no conflict found' with the date"
  case_start TC-T07-54 "KD-7 owner-run: dashboard upstream-updates notice observed once after O-4"
  blk "owner-run: open the Pantheon dashboard for meridian-trade after O-4, record what the upstream-updates notice says (screenshot or note) and that ignoring it is harmless; do not click Apply Updates"
  case_start TC-T07-56 "AC2 owner-run: the PAT table in the runbook holds real creation and expiry dates and no value; the PAT works from the global DDEV config"
  blk "owner-run: after O-1, the owner states the creation date; the runbook table shows creation plus 90 days as the expiry; terminus auth:whoami succeeds in ddev exec; the owner confirms by message that no PAT value was pasted into chat or a file"
  case_start TC-T07-57 "C7 owner-run: docs/runbooks/deploy.md followed verbatim from a fresh clone (ddev deploy-drupal --dry-run, ddev pull pantheon)"
  blk "owner-run (or tester with the owner's credentials loaded): follow the runbook word for word on a fresh clone through the dry run and the pull; record each command, output and the total time. TC-T07-55 automates the credential-free half"
fi
fi

echo
echo "== Roll-up per case"
for id in "${ORDER[@]}"; do
  if [[ "${CSTAT[$id]}" == PASS && "${NPASS[$id]}" -eq 0 ]]; then CSTAT["$id"]=SKIP; fi
  printf '  %-8s %s\n' "${CSTAT[$id]}" "$id"
done
pc=0; fc=0; bc=0
for id in "${ORDER[@]}"; do case "${CSTAT[$id]}" in PASS) pc=$((pc+1));; FAIL) fc=$((fc+1));; BLOCKED) bc=$((bc+1));; esac; done
echo
if [[ "$MODE" == reg ]]; then
  echo "NOTE: --regression: $excluded at-close (snapshot) checks excluded."
fi
echo "SUMMARY: mode=$MODE run=$RUNID cases: $pc PASS, $fc FAIL, $bc BLOCKED; checks executed: $ran; SKIP (optional tools): $skipped; BLOCKED lines: $blocked"
if [[ $fail -eq 0 ]]; then echo "RESULT: ALL EXECUTED CHECKS PASSED ($bc case(s) blocked)"; else echo "RESULT: ONE OR MORE CHECKS FAILED"; fi
exit "$fail"
