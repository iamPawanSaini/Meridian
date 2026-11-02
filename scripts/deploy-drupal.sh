#!/usr/bin/env bash
# Deploy apps/drupal to Pantheon dev (T07, plan KD-1). The only implementation of the deploy
# steps: `ddev deploy-drupal` and .github/workflows/deploy-drupal.yml are thin wrappers.
#
# Usage: scripts/deploy-drupal.sh [--ref REF] [--dry-run] [--allow-unmerged] [-h]
#   --ref REF          commit to deploy (default HEAD); resolved with git rev-parse --verify
#   --dry-run          split the tree and check it, print the split SHA and the target; no network
#   --allow-unmerged   allow a REF that is not an ancestor of origin/main (prints a warning)
#   -h, --help         show this text
#
# Environment:
#   PANTHEON_SITE           required: Pantheon site machine name
#   TERMINUS_MACHINE_TOKEN  optional: Pantheon personal access token (PAT). When set, the script
#                           runs terminus auth:login; otherwise it needs an existing session
#                           (terminus auth:whoami prints an email)
#   DEPLOY_SMOKE_BUDGET     optional: whole seconds the smoke check retries while the site wakes
#                           (default 120; anything else exits 2). In DDEV: ddev exec env
#                           DEPLOY_SMOKE_BUDGET=300 scripts/deploy-drupal.sh. In CI: repository
#                           variable DEPLOY_SMOKE_BUDGET (passed by the workflow)
#   DEPLOY_SMOKE_HEADER     optional: one extra request header for the smoke check, for example
#                           "Deterrence-Bypass: 1" if the Sandbox warning page intercepts curl
#                           (the value is measured in T07, KD-12; it is not a secret). Set it the
#                           same way as DEPLOY_SMOKE_BUDGET (CI variable DEPLOY_SMOKE_HEADER)
#
# Exit status: 0 deployed and verified; 1 a deploy or verification step failed (including the
# split tree guard and an unconfirmed build); 2 usage error or a guard: bad or unknown argument,
# PANTHEON_SITE unset, DEPLOY_SMOKE_BUDGET not whole seconds, unknown ref, missing origin/main,
# ref not merged into origin/main, no code server key in scripts/pantheon_known_hosts, or a
# git_url of an unexpected form.
#
# Re-run: when Pantheon master already equals the split SHA, the backup and the push are skipped,
# but the build of that commit must still be confirmed (stage 6), or the script exits 1.
# Run from any directory inside the repository.
#
# The script never forces a push, never uses a "+" refspec and never prints the token. It has no
# shell tracing on purpose, so no variable can leak into a log.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWN_HOSTS="$SCRIPT_DIR/pantheon_known_hosts"
RUNBOOK="docs/runbooks/deploy.md"

# Code server: strict host key checking against the pinned file (SA-4).
# GlobalKnownHostsFile=/dev/null: a key in /etc/ssh/ssh_known_hosts must not override the pin.
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=$KNOWN_HOSTS -o BatchMode=yes"
# App server (drush) is deliberately not pinned: Pantheon changes its key at container
# migrations. env:code-log and the HTTPS smoke check verify the result instead (SA-4).
export TERMINUS_SSH_COMMAND='ssh -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR'
# Terminus swaps host names for IP addresses when this is set, which breaks host key pinning.
unset TERMINUS_ALTERNATE_NAMESERVER

usage() {
  sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed -e '/^set -euo/d' -e 's/^# \{0,1\}//' -e '/^#$/d'
}

stage() {
  printf 'deploy-drupal: stage %s: %s\n' "$1" "$2"
}

# fail MESSAGE [CODE]: one line on stderr, then exit (default 1).
fail() {
  printf 'deploy-drupal: error: %s\n' "$1" >&2
  exit "${2:-1}"
}

# redact TEXT: the PAT must not reach a log even if Terminus echoes it.
redact() {
  local text="$1"
  if [[ -n "${TERMINUS_MACHINE_TOKEN:-}" ]]; then
    text="${text//"$TERMINUS_MACHINE_TOKEN"/[REDACTED]}"
  fi
  printf '%s' "$text"
}

ref="HEAD"
dry_run=0
allow_unmerged=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      [[ $# -ge 2 ]] || fail "--ref needs a value" 2
      ref="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --allow-unmerged)
      allow_unmerged=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument '$1' (see -h)" 2
      ;;
  esac
done

# git subtree must run at the top level (git-sh-setup), and the paths below are repo-relative.
top="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)" || fail "not inside a git work tree" 2
cd "$top" || fail "cannot enter $top" 2

site="${PANTHEON_SITE:-}"
[[ -n "$site" ]] || fail "PANTHEON_SITE is not set (the Pantheon site machine name)" 2
env_id="$site.dev"
budget="${DEPLOY_SMOKE_BUDGET:-120}"
[[ "$budget" =~ ^[0-9]+$ ]] || fail "DEPLOY_SMOKE_BUDGET must be whole seconds, got '$budget'" 2

# ---- Stage 1: resolve and guard the ref -------------------------------------------------------
stage 1 "resolve and guard the ref"
commit="$(git rev-parse --verify --quiet "$ref^{commit}")" || fail "cannot resolve ref '$ref'" 2
git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null \
  || fail "origin/main is missing; run git fetch origin first" 2
if ! git merge-base --is-ancestor "$commit" refs/remotes/origin/main; then
  if [[ "$allow_unmerged" -ne 1 ]]; then
    fail "$ref is not merged into origin/main; merge it first or pass --allow-unmerged" 2
  fi
  echo "deploy-drupal: warning: $ref is not on origin/main. Merge this branch into main with a" \
    "merge commit (no squash, no rebase), or the next deploy of main is rejected as a rewind."
fi
# No -b: the split makes no branch or ref. The split is deterministic, so a later split of main
# descends from a split of a task branch that was merged with a merge commit.
split_sha="$(git subtree split -q --prefix=apps/drupal "$commit")" \
  || fail "git subtree split failed for $ref"
[[ "$split_sha" =~ ^[0-9a-f]{40}$ ]] || fail "git subtree split returned no commit for $ref"

# ---- Stage 2: guard the split tree ------------------------------------------------------------
stage 2 "guard the split tree"
tree_files="$(git ls-tree -r --name-only "$split_sha")"
forbidden="$(grep -E '^vendor/|^web/core/|^web/modules/contrib/|^web/sites/[^/]+/files/|^private/|(^|/)\.env$|\.(key|pem)$|(^|/)settings\.local\.php$' <<<"$tree_files" || true)"
if [[ -n "$forbidden" ]]; then
  echo "$forbidden" | head -5 >&2
  fail "the split tree holds build output, secrets or local files (first paths above)"
fi
for required in composer.json composer.lock pantheon.yml config/sync/system.site.yml; do
  grep -qxF "$required" <<<"$tree_files" || fail "the split tree lacks $required"
done
echo "deploy-drupal: split $split_sha of $ref for $env_id"
if [[ "$dry_run" -eq 1 ]]; then
  echo "deploy-drupal: dry run, no network. Would deploy split $split_sha to $env_id"
  exit 0
fi

# ---- Stage 3: authenticate --------------------------------------------------------------------
stage 3 "authenticate"
if [[ -n "${TERMINUS_MACHINE_TOKEN:-}" ]]; then
  # Terminus reads the PAT only from this option (checked in the 4.3.3 source, LoginCommand), so
  # it is on the command line of this one process. The output is scrubbed before it is shown.
  if ! login_out="$(terminus auth:login --machine-token="$TERMINUS_MACHINE_TOKEN" 2>&1)"; then
    redact "$login_out" >&2
    printf '\n' >&2
    fail "terminus auth:login failed (expired or wrong PAT? see $RUNBOOK, token rotation)"
  fi
else
  # auth:whoami exits 0 when logged out (it only logs "You are not logged in." to stderr, 4.3.3
  # WhoamiCommand), so the email on stdout is the test, not the exit status.
  who="$(terminus auth:whoami --field=email 2>/dev/null || true)"
  [[ -n "${who//[[:space:]]/}" ]] \
    || fail "no TERMINUS_MACHINE_TOKEN and no Terminus session; set the PAT (see $RUNBOOK)"
fi
git_url="$(terminus connection:info "$env_id" --field=git_url)" \
  || fail "terminus connection:info failed for $env_id"
[[ -n "$git_url" ]] || fail "no git_url for $env_id"
if [[ "$git_url" == ssh://* ]]; then
  git_host="${git_url#ssh://}"
  git_host="${git_host#*@}"
  git_host="${git_host%%[:/]*}"
  grep -qvE '^[[:space:]]*(#|$)' "$KNOWN_HOSTS" 2>/dev/null \
    || fail "$KNOWN_HOSTS holds no host key line; record the code server key first (see $RUNBOOK)" 2
  echo "deploy-drupal: code server $git_host (host key pinned in scripts/pantheon_known_hosts)"
elif [[ "$git_url" == /* || "$git_url" == file://* ]]; then
  # Only a local path passes without a pinned key: the offline test harness uses one.
  echo "deploy-drupal: code server is a local path (test setup)"
else
  fail "unexpected git_url form '$git_url' (expected ssh://)" 2
fi

# ---- Stage 4: wake and look for an earlier push of the same commit ---------------------------
stage 4 "wake $env_id"
terminus env:wake "$env_id" || fail "terminus env:wake failed for $env_id"
remote_head="$(git ls-remote "$git_url" refs/heads/master | cut -f1)" \
  || fail "git ls-remote failed (host key mismatch or no SSH key? see $RUNBOOK, Troubleshooting)"
if [[ "$remote_head" == "$split_sha" ]]; then
  echo "deploy-drupal: master is already at $split_sha; backup and push skipped, build still checked"
  # --start=1 accepts the earlier workflow of this commit (the default window is the last 60 s).
  wait_args=(--start=1)
else
  # ---- Stage 5: back up the database, then push without force ---------------------------------
  stage 5 "back up the database, then push $split_sha"
  terminus backup:create "$env_id" --element=db --keep-for=30 \
    || fail "database backup failed; nothing was pushed"
  if ! git push "$git_url" "$split_sha:refs/heads/master"; then
    fail "push rejected or failed. If it was a rewind, see $RUNBOOK sections 'Roll back code' and 'Emergency force push'"
  fi
  wait_args=()
fi

# ---- Stage 6: confirm the build and verify the code out of band (every run) -------------------
stage 6 "wait for the workflow and check the code log"
# Terminus 4.3.3 WaitCommand::waitForCommit (docs/tasks/T07/terminus-4.3.3-facts.md): it matches
# the newest workflow of this environment and commit, throws (exit 1) if it ends Failed or
# Aborted, and exits 0 with a warning when it gives up or finds no workflow. So success needs the
# line "completed successfully for commit" in the output, not only exit 0.
wait_out="$(terminus workflow:wait "$env_id" --commit="$split_sha" --max=900 ${wait_args[@]+"${wait_args[@]}"} 2>&1)" \
  || { printf '%s\n' "$wait_out" >&2; fail "workflow:wait failed for $split_sha (build failed or aborted? see the dashboard workflow log)"; }
printf '%s\n' "$wait_out"
if grep -qi 'giving up' <<<"$wait_out"; then
  fail "the workflow for $split_sha did not finish within 900 s; build of $split_sha not confirmed"
fi
grep -q "completed successfully for commit" <<<"$wait_out" \
  || fail "build of $split_sha not confirmed (no successful workflow found); check the dashboard workflow log"
code_log="$(terminus env:code-log "$env_id" --format=json)" \
  || fail "terminus env:code-log failed for $env_id"
newest="$(grep -oE '"hash" *: *"[0-9a-f]{40}"' <<<"$code_log" | head -1 | grep -oE '[0-9a-f]{40}' || true)"
[[ "$newest" == "$split_sha" ]] \
  || fail "env:code-log newest commit is '${newest:-none}', expected $split_sha"

# ---- Stage 7: apply updates and config --------------------------------------------------------
stage 7 "updatedb, config:import, cache:rebuild"
terminus remote:drush "$env_id" -- updatedb -y || fail "drush updatedb failed"
terminus remote:drush "$env_id" -- config:import -y || fail "drush config:import failed"
terminus remote:drush "$env_id" -- cache:rebuild || fail "drush cache:rebuild failed"

# ---- Stage 8: config check --------------------------------------------------------------------
stage 8 "config:status"
config_out="$(terminus remote:drush "$env_id" -- config:status 2>&1)" \
  || { printf '%s\n' "$config_out" >&2; fail "drush config:status failed"; }
printf '%s\n' "$config_out"
grep -q 'No differences' <<<"$config_out" \
  || fail "config:status reports differences between the database and config/sync"

# ---- Stage 9: smoke check over HTTPS ----------------------------------------------------------
stage 9 "smoke check"
smoke_host="dev-$site.pantheonsite.io"
url="https://$smoke_host/user/login"
body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
extra_header=()
[[ -z "${DEPLOY_SMOKE_HEADER:-}" ]] || extra_header=(-H "$DEPLOY_SMOKE_HEADER")
code="000"
smoke_ok=0
smoke_start="$SECONDS"
while :; do
  code="$(curl -sS --max-time 30 -o "$body_file" -w '%{http_code}' ${extra_header[@]+"${extra_header[@]}"} "$url" 2>/dev/null)" || code="000"
  # The marker proves this is Drupal's form and not the Sandbox warning page.
  if [[ "$code" == "200" ]] && grep -q 'user-login-form' "$body_file"; then
    smoke_ok=1
    break
  fi
  [[ $((SECONDS - smoke_start)) -lt "$budget" ]] || break
  echo "deploy-drupal: smoke check got HTTP $code without the login form; retrying (the site may be waking)"
  sleep 10
done
[[ "$smoke_ok" -eq 1 ]] || fail "smoke check failed: last HTTP status $code, no user-login-form in the body ($url)"
echo "deploy-drupal: smoke check passed: HTTP 200 with user-login-form at $url"

echo "deploy-drupal: deployed $split_sha"
