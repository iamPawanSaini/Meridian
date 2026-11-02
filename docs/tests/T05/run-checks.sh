#!/usr/bin/env bash
# Automated checks for T05 (DDEV Drupal project). Designed from the acceptance criteria in docs/TASKS.md,
# the approved plan docs/tasks/T05/plan.md (KD-1 to KD-8) and the common criteria C1 to C7, NOT from the
# implementation. Failing before the implementation exists is expected.
#
# Usage:
#   docs/tests/T05/run-checks.sh                static checks, TC-T05-01 to 24 (no network, no DDEV)
#   docs/tests/T05/run-checks.sh --regression   invariant static checks only (CI PR set, decision D-5)
#   docs/tests/T05/run-checks.sh --live          static checks, then live checks TC-T05-25 to 36 against
#                                                the running project in this working tree (needs DDEV,
#                                                Docker, network; mutates the local DB: reinstalls Drupal)
#   docs/tests/T05/run-checks.sh --live-only     live checks only
#   T05_CONFIRM=1 docs/tests/T05/run-checks.sh --clean-clone
#                                                TC-T05-37, 38 then the live set inside a fresh clone in a
#                                                scratch dir. Runs `ddev stop --unlist meridian` first and
#                                                restarts this working tree at the end; needs T05_CONFIRM=1.
#   Environment: T05_EVIDENCE=1 also writes each case's lines to docs/tests/T05/evidence/TC-T05-nn.txt.
#
# Output: one line per check (PASS / FAIL / BLOCKED / SKIP), then one roll-up line per case, then a
# summary. Exit status is 1 if any check FAILs, else 0. A missing file makes every dependent check FAIL
# (no vacuous pass). SKIP is only for optional host tools (shellcheck, composer, pre-commit, gitleaks),
# and is counted and printed. BLOCKED means the environment cannot run the case (no DDEV, no network,
# owner-run); it is not a pass, does not change the exit status, and the report must list each one.
#
# Tags (decision D-5): ckp = invariant (runs in all static modes); cka = snapshot, true only at the
# close of T05 (e.g. phpunit.xml.dist absent until T09); skipped by --regression, count printed.
# shellcheck disable=SC2329,SC2015,SC2016,SC2034 # T05: check helpers are called through ckp/cka by name; regexes are literal
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel) || exit 2
cd "$ROOT"
T=docs/tests/T05
EVD=$ROOT/$T/evidence

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
CASE=""; CASE_FAIL=0
declare -a ORDER=()
declare -A CSTAT=()
declare -A NPASS=()

emit() {
  printf '%s\n' "$1"
  if [[ "${T05_EVIDENCE:-0}" == 1 && -n "$CASE" ]]; then
    mkdir -p "$EVD"
    printf '%s\n' "$1" >>"$EVD/$CASE.txt"
  fi
}
case_start() {   # ID TITLE
  CASE=$1; CASE_FAIL=0; ORDER+=("$1"); CSTAT["$1"]=PASS; NPASS["$1"]=0
  [[ "${T05_EVIDENCE:-0}" == 1 ]] && { mkdir -p "$EVD"; : >"$EVD/$1.txt"; }
  emit "== $1 $2"
}
pass() { emit "  PASS  $1"; NPASS["$CASE"]=$((NPASS["$CASE"]+1)); }
bad()  { emit "  FAIL  $1"; fail=1; CSTAT["$CASE"]=FAIL; }
skip() { emit "  SKIP  $1"; skipped=$((skipped+1)); }
blk()  {
  emit "  BLOCKED  $1"; blocked=$((blocked+1))
  [[ "${CSTAT[$CASE]}" == FAIL ]] || CSTAT["$CASE"]=BLOCKED
}
show_out() { local line; while IFS= read -r line; do emit "        $line"; done < <(printf '%s\n' "$1" | head -8); }
# ckp DESC CMD...: invariant. cka DESC CMD...: snapshot (not run with --regression).
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

WORK=$(mktemp -d "${TMPDIR:-/tmp}/t05.XXXXXX")
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ---------- python helpers (read-only parsing of YAML and JSON) ----------
cat >"$WORK/h.py" <<'PY'
import json, sys
kind, path, key = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else "")
try:
    if kind == "y":
        import yaml
        with open(path, encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
    else:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
except Exception as exc:  # parse failure or missing file
    print(f"cannot parse {path}: {exc}", file=sys.stderr)
    sys.exit(3)
cur = data
if key:
    for part in key.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            sys.exit(1)
if isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, (dict, list)):
    print(json.dumps(cur, sort_keys=True))
elif cur is None:
    print("null")
else:
    print(cur)
PY
yget() { python3 -I "$WORK/h.py" y "$1" "${2:-}"; }
jget() { python3 -I "$WORK/h.py" j "$1" "${2:-}"; }
eq() {   # DESC-less equality helper: eq ACTUAL EXPECTED LABEL
  [[ "$1" == "$2" ]] || { echo "$3: expected '$2', got '$1'"; return 1; }
}
need_file() { [[ -s "$1" ]] || { echo "missing or empty: $1"; return 1; }; }
yeq() { local v; need_file "$1" || return 1; v=$(yget "$1" "$2") || { echo "$1: key '$2' missing or file unparsable"; return 1; }
  eq "$v" "$3" "$1 $2"; }
jeq() { local v; need_file "$1" || return 1; v=$(jget "$1" "$2") || { echo "$1: key '$2' missing or file unparsable"; return 1; }
  eq "$v" "$3" "$1 $2"; }
allin() { local f=$1 p; shift; need_file "$f" || return 1
  for p in "$@"; do grep -qiE -- "$p" "$f" || { echo "missing in $f: $p"; return 1; }; done; }
allout() { local f=$1 p; shift; need_file "$f" || return 1
  for p in "$@"; do ! grep -qiE -- "$p" "$f" || { echo "unexpected in $f: $p"; return 1; }; done; }

DDEVCFG=.ddev/config.yaml
PANT=apps/drupal/pantheon.yml
CJ=apps/drupal/composer.json
CL=apps/drupal/composer.lock
SET=apps/drupal/web/sites/default/settings.php
SYNC=apps/drupal/config/sync
DI=.ddev/commands/web/drupal-install
HQ=.ddev/commands/host/quality
RB=docs/runbooks/local-setup.md
QS=scripts/quality.sh
ADR=apps/drupal/README.md

t05_files() { git ls-files -co --exclude-standard -- apps/drupal .ddev "$RB" "$QS" | grep -vE '^apps/drupal/composer\.lock$' || true; }

# =====================================================================================================
if [[ "$MODE" != liveonly && "$MODE" != clone ]]; then

case_start TC-T05-01 "DDEV project configuration keys (AC1)"
ckp "name is meridian" yeq "$DDEVCFG" name meridian
ckp "type is drupal11" yeq "$DDEVCFG" type drupal11
ckp "composer_root is apps/drupal" yeq "$DDEVCFG" composer_root apps/drupal
ckp "docroot is apps/drupal/web (relative to the project root, not the composer root)" yeq "$DDEVCFG" docroot apps/drupal/web
ckp "webserver_type is nginx-fpm" yeq "$DDEVCFG" webserver_type nginx-fpm
ckp "database type is mariadb" yeq "$DDEVCFG" database.type mariadb
ckp "xdebug off by default" yeq "$DDEVCFG" xdebug_enabled false
short_cfg() { need_file "$DDEVCFG" || return 1; local n; n=$(wc -l <"$DDEVCFG")
  [[ $n -le 60 ]] || { echo "config.yaml has $n lines: hand-written short file expected (KD-3)"; return 1; }
  ! grep -q '#ddev-generated' "$DDEVCFG" || { echo "config.yaml carries the ddev-generated marker"; return 1; }; }
ckp "config.yaml is short and hand-written (no full commented ddev config output)" short_cfg

case_start TC-T05-02 "DDEV hook, settings management and no secrets in config (AC1, C6)"
hook_ok() { local v; need_file "$DDEVCFG" || return 1
  v=$(yget "$DDEVCFG" hooks.post-start) || { echo "hooks.post-start missing"; return 1; }
  grep -q 'composer' <<<"$v" && grep -q 'install' <<<"$v" || { echo "post-start does not run composer install: $v"; return 1; }; }
ckp "post-start hook runs composer install (vendor matches the lock after ddev start)" hook_ok
no_dsm() { need_file "$DDEVCFG" || return 1; ! grep -qE '^\s*disable_settings_management\s*:\s*true' "$DDEVCFG" \
  || { echo "disable_settings_management must not be true (KD-3)"; return 1; }; }
ckp "settings management stays on" no_dsm
ckp "no web_environment secrets, tokens or keys in config.yaml" allout "$DDEVCFG" \
  'web_environment' '(api[_-]?key|secret|token|password|passwd)\s*[:=]\s*\S'
ckp "no extra hostnames or additional_hostnames (T06 owns meridian-web)" allout "$DDEVCFG" 'additional_(hostnames|fqdns)\s*:\s*\[?\s*\S'
ckp "no Mutagen or performance_mode override" allout "$DDEVCFG" '^\s*performance_mode\s*:'

case_start TC-T05-03 "pantheon.yml keys (AC3)"
ckp "api_version 1" yeq "$PANT" api_version 1
ckp "web_docroot true" yeq "$PANT" web_docroot true
ckp "build_step true (Integrated Composer)" yeq "$PANT" build_step true
ckp "php_version is a major.minor number" bash -c "v=\$(python3 -I '$WORK/h.py' y '$PANT' php_version) && [[ \$v =~ ^[0-9]+\.[0-9]+\$ ]]"
ckp "database.version present" bash -c "python3 -I '$WORK/h.py' y '$PANT' database.version >/dev/null"
ckp "no drush_version key (Drush comes from vendor)" bash -c "! grep -qE '^\s*drush_version' '$PANT'"
ckp "no pantheon.upstream.yml is tracked" bash -c "[[ -z \$(git ls-files | grep -E 'pantheon\.upstream\.yml' || true) ]]"
ckp "pantheon.yml is at the composer root apps/drupal (subtree split root, ADR-0004)" test -f "$PANT"

case_start TC-T05-04 "PHP and database version parity, three-way (AC3)"
parity_php() { local p d c; need_file "$PANT" && need_file "$DDEVCFG" && need_file "$CJ" || return 1
  p=$(yget "$PANT" php_version) || return 1; d=$(yget "$DDEVCFG" php_version) || return 1
  c=$(jget "$CJ" config.platform.php) || { echo "composer.json config.platform.php missing"; return 1; }
  c=${c%.*}
  [[ "$p" == "$d" && "$p" == "$c" ]] || { echo "php mismatch: pantheon=$p ddev=$d composer.platform(major.minor)=$c"; return 1; }; }
ckp "pantheon.yml php_version == .ddev php_version == composer config.platform.php (major.minor)" parity_php
parity_db() { local p d; p=$(yget "$PANT" database.version) || return 1; d=$(yget "$DDEVCFG" database.version) || return 1
  [[ "$p" == "$d" ]] || { echo "db mismatch: pantheon=$p ddev=$d"; return 1; }; }
ckp "pantheon.yml database.version == .ddev database.version" parity_db
platform_full() { local c; c=$(jget "$CJ" config.platform.php) || return 1
  [[ "$c" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "config.platform.php '$c' is not x.y.z"; return 1; }; }
ckp "composer config.platform.php is a full x.y.z version" platform_full
php_floor() { local p; p=$(yget "$PANT" php_version) || return 1
  python3 -I -c "import sys; a=tuple(map(int,sys.argv[1].split('.'))); sys.exit(0 if a>=(8,3) else 1)" "$p" \
    || { echo "php_version $p is below the Drupal 11 floor 8.3"; return 1; }; }
ckp "php_version is 8.3 or later (CODING_STANDARDS.md and Drupal 11 floor)" php_floor
db_floor() { local p; p=$(yget "$PANT" database.version) || return 1
  python3 -I -c "import sys; a=tuple(map(int,sys.argv[1].split('.'))); sys.exit(0 if a>=(10,6) else 1)" "$p" \
    || { echo "database.version $p is below the Drupal 11 floor 10.6"; return 1; }; }
ckp "database.version is 10.6 or later" db_floor
skew_selftest() {   # harness self-test: a skewed fixture must not equal the expected value
  printf 'php_version: 8.4\n' >"$WORK/skew.yml"
  [[ "$(yget "$WORK/skew.yml" php_version)" != "8.3" ]]; }
ckp "negative: harness self-test, a skewed php_version fixture (8.4) does not equal 8.3" skew_selftest

case_start TC-T05-05 "composer.json structure (AC5, KD-1)"
ckp "composer.json is valid JSON" bash -c "python3 -I '$WORK/h.py' j '$CJ' name >/dev/null"
ckp "name meridian/drupal" jeq "$CJ" name meridian/drupal
ckp "type project" jeq "$CJ" type project
ckp "license key present" bash -c "python3 -I '$WORK/h.py' j '$CJ' license >/dev/null"
ckp "minimum-stability stable" jeq "$CJ" minimum-stability stable
ckp "prefer-stable true" jeq "$CJ" prefer-stable true
ckp "config.sort-packages true" jeq "$CJ" config.sort-packages true
req_ok() { local r p; r=$(jget "$CJ" require) || { echo "no require block"; return 1; }
  for p in composer/installers drupal/core-composer-scaffold drupal/core-recommended drush/drush pantheon-systems/drupal-integrations; do
    grep -q "\"$p\"" <<<"$r" || { echo "require lacks $p"; return 1; }; done; }
ckp "require has the five planned packages" req_ok
req_only() { local r; r=$(jget "$CJ" require) || return 1
  python3 -I -c "
import json,sys
ok={'composer/installers','drupal/core-composer-scaffold','drupal/core-recommended','drush/drush','pantheon-systems/drupal-integrations','php'}
extra=[k for k in json.loads(sys.argv[1]) if k not in ok]
if extra: print('unplanned require entries (contrib modules arrive in T09/T10):', extra); sys.exit(1)" "$r"; }
ckp "require holds nothing else (no JSON:API, Simple OAuth or other contrib)" req_only
ckp "require-dev has drupal/core-dev" bash -c "python3 -I '$WORK/h.py' j '$CJ' require-dev | grep -q 'drupal/core-dev'"
ckp "repositories include https://packages.drupal.org/8" bash -c "python3 -I '$WORK/h.py' j '$CJ' repositories | grep -q 'packages.drupal.org/8'"
ckp "no upstream-configuration path repository or script (ADR-0004: subtree deploy)" bash -c "! grep -q 'upstream-configuration' '$CJ'"
allow_ok() { local a; a=$(jget "$CJ" config.allow-plugins) || { echo "config.allow-plugins missing"; return 1; }
  python3 -I -c "
import json,sys
d=json.loads(sys.argv[1])
if not isinstance(d,dict) or not d: print('allow-plugins must be a non-empty map'); sys.exit(1)
if '*' in d: print('wildcard allow-plugins entry'); sys.exit(1)
bad=[k for k,v in d.items() if v is not True and v is not False]
if bad: print('non-boolean entries', bad); sys.exit(1)
for need in ('composer/installers','drupal/core-composer-scaffold'):
    if d.get(need) is not True: print('not allowed:', need); sys.exit(1)" "$a"; }
ckp "allow-plugins explicit, no wildcard, installers and scaffold allowed" allow_ok
ckp "scaffold web-root is web/" jeq "$CJ" extra.drupal-scaffold.locations.web-root "web/"
ckp "pantheon-systems/drupal-integrations is in scaffold allowed-packages" bash -c \
  "python3 -I '$WORK/h.py' j '$CJ' extra.drupal-scaffold.allowed-packages | grep -q 'pantheon-systems/drupal-integrations'"
paths_ok() { local p s; p=$(jget "$CJ" extra.installer-paths) || { echo "extra.installer-paths missing"; return 1; }
  for s in web/core 'web/modules/contrib' 'web/themes/contrib' 'web/profiles/contrib' 'web/libraries' 'drush/Commands/contrib' 'web/modules/custom'; do
    grep -qF "$s" <<<"$p" || { echo "installer-paths lacks $s"; return 1; }; done; }
ckp "installer-paths: core, contrib, libraries, drush, custom" paths_ok

case_start TC-T05-06 "composer.lock committed and consistent (AC5, KD-1)"
ckp "composer.lock is valid JSON with a content-hash" bash -c "python3 -I '$WORK/h.py' j '$CL' content-hash | grep -qE '^[0-9a-f]{32}\$'"
lock_pkgs() { need_file "$CL" || return 1
  python3 -I -c "
import json,sys
d=json.load(open(sys.argv[1]))
names={p['name']:p for p in d.get('packages',[])+d.get('packages-dev',[])}
need=['drupal/core','drupal/core-recommended','drush/drush','pantheon-systems/drupal-integrations','drupal/core-dev','composer/installers','drupal/core-composer-scaffold']
miss=[n for n in need if n not in names]
if miss: print('lock lacks', miss); sys.exit(1)
if not names['drupal/core']['version'].lstrip('v').startswith('11.'): print('drupal/core is not 11.x:', names['drupal/core']['version']); sys.exit(1)
if int(names['drush/drush']['version'].lstrip('v').split('.')[0])<13: print('drush < 13'); sys.exit(1)
print(len(names),'packages')" "$CL"; }
ckp "lock holds core 11.x, Drush 13 or later, the Pantheon integration, core-dev" lock_pkgs
lock_plat() { local c l; c=$(jget "$CJ" config.platform.php) || return 1; l=$(jget "$CL" platform-overrides.php) \
  || { echo "lock has no platform-overrides.php: lock was not resolved for the platform"; return 1; }; eq "$l" "$c" "lock platform-overrides.php"; }
ckp "lock platform-overrides.php equals composer.json config.platform.php" lock_plat
plugins_listed() { need_file "$CL" && need_file "$CJ" || return 1
  python3 -I -c "
import json,sys
l=json.load(open(sys.argv[1])); c=json.load(open(sys.argv[2]))
allow=c.get('config',{}).get('allow-plugins',{})
plug=[p['name'] for p in l.get('packages',[])+l.get('packages-dev',[]) if p.get('type')=='composer-plugin']
miss=[n for n in plug if n not in allow]
if miss: print('composer-plugin packages not decided in allow-plugins:', miss); sys.exit(1)" "$CL" "$CJ"; }
ckp "every composer-plugin package in the lock has an explicit allow-plugins decision" plugins_listed
tools_in_lock() { python3 -I -c "
import json,sys
d=json.load(open(sys.argv[1]))
n={p['name'] for p in d.get('packages',[])+d.get('packages-dev',[])}
need=['squizlabs/php_codesniffer','drupal/coder','phpstan/phpstan','mglaman/phpstan-drupal','phpstan/phpstan-deprecation-rules','phpunit/phpunit']
miss=[x for x in need if x not in n]
if miss: print('dev tools missing from lock:', miss); sys.exit(1)" "$CL"; }
ckp "lock contains phpcs, Drupal coder, PHPStan, phpstan-drupal, deprecation rules, PHPUnit" tools_in_lock
composer_validate_static() { command -v composer >/dev/null 2>&1 || return 42
  composer validate --no-check-publish --no-interaction -d apps/drupal; }
if command -v composer >/dev/null 2>&1; then
  ckp "host composer validate (lock matches composer.json)" composer_validate_static
else skip "host composer not installed: lock freshness is covered by TC-T05-27 (ddev composer validate)"; fi
ckp "vendor/ and web/core are not tracked" bash -c "[[ -z \$(git ls-files apps/drupal/vendor apps/drupal/web/core | head -1) ]]"

case_start TC-T05-07 "settings.php include order and config sync directory (AC4, KD-4)"
nc() { grep -nE -- "$1" "$SET" | grep -vE '^[0-9]+:\s*(#|//|\*|/\*)' | head -1 | cut -d: -f1; }
need_set() { need_file "$SET"; }
ckp "settings.php exists and lints (php -l, if PHP present)" bash -c "[[ -s '$SET' ]] && { ! command -v php >/dev/null || php -l '$SET' >/dev/null; }"
ckp "config_sync_directory is '../config/sync' (resolves to apps/drupal/config/sync)" bash -c \
  "grep -vE '^\s*(#|//|\*|/\*)' '$SET' | grep -qE \"[\\$]settings\\['config_sync_directory'\\]\\s*=\\s*['\\\"]\\.\\./config/sync['\\\"]\""
order_ok() { need_set || return 1; local a b c d
  a=$(nc 'settings\.pantheon\.php'); b=$(nc 'settings\.ddev\.php'); c=$(nc "config_sync_directory"); d=$(nc 'settings\.local\.php')
  [[ -n "$a" && -n "$b" && -n "$c" && -n "$d" ]] || { echo "missing include or setting: pantheon=$a ddev=$b sync=$c local=$d"; return 1; }
  [[ $a -lt $b && $b -lt $c && $c -lt $d ]] || { echo "order wrong (lines): pantheon=$a ddev=$b sync=$c local=$d; need pantheon < ddev < sync < local"; return 1; }; }
ckp "order: settings.pantheon.php < settings.ddev.php < config_sync_directory < settings.local.php" order_ok
ckp "pantheon, ddev and local includes are guarded by file_exists()" bash -c \
  "for f in settings.pantheon.php settings.ddev.php settings.local.php; do grep -E \"\$f\" '$SET' | grep -vE '^\s*(#|//|\*|/\*)' | grep -q . || exit 1; grep -B3 \"\$f\" '$SET' | grep -q file_exists || { echo \"no file_exists near \$f\"; exit 1; }; done"
ckp "DDEV block is conditional on IS_DDEV_PROJECT" allin "$SET" "IS_DDEV_PROJECT"
ckp "skip_permissions_hardening set as in the upstream" allin "$SET" "skip_permissions_hardening"
ckp "file_private_path and OAuth key paths are NOT set yet (T10)" allout "$SET" "^\s*\\\$settings\['file_private_path'\]" 'oauth|private_key|public_key'

case_start TC-T05-08 "settings.php carries no secrets (C6, D7)"
ckp "no literal hash_salt" bash -c "[[ -s '$SET' ]] && ! grep -vE '^\s*(#|//|\*|/\*)' '$SET' | grep -qE \"hash_salt'\\]\\s*=\\s*['\\\"][^'\\\"]+['\\\"]\""
ckp "no literal database credentials" bash -c "[[ -s '$SET' ]] && ! grep -vE '^\s*(#|//|\*|/\*)' '$SET' | grep -qE \"'(password|username|host)'\\s*=>\\s*['\\\"][^'\\\"]+['\\\"]\""
ckp "no key material, API key or token pattern" bash -c "[[ -s '$SET' ]] && ! grep -qE 'BEGIN [A-Z ]*PRIVATE KEY|sk-ant-|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20}|(api[_-]?key|secret)\s*[=:]\s*[\"'\\'']?[A-Za-z0-9]{16,}' '$SET'"
ckp "databases array is reset empty and not populated with literals" allin "$SET" '\$databases\s*=\s*\[\s*\]'
ckp "settings.ddev.php, settings.local.php and settings.pantheon.php are not tracked" bash -c \
  "[[ -z \$(git ls-files apps/drupal/web/sites | grep -E 'settings\.(ddev|local|pantheon)\.php' || true) ]]"

case_start TC-T05-09 "git ignore rules and the generated-file invariant (KD-7)"
ign() { git check-ignore -q -- "$1" || { echo "NOT ignored but must be: $1"; return 1; }; }
nign() { [[ -e "$1" ]] || { echo "owned file missing: $1"; return 1; }
  ! git check-ignore -q -- "$1" || { echo "ignored but must be tracked: $1"; return 1; }; }
for p in apps/drupal/vendor/autoload.php apps/drupal/web/core/index.php apps/drupal/web/modules/contrib/x/x.info.yml \
  apps/drupal/web/themes/contrib/x/x.info.yml apps/drupal/web/profiles/contrib/x/x.info.yml apps/drupal/web/libraries/x/x.js \
  apps/drupal/web/sites/default/settings.ddev.php apps/drupal/web/sites/default/settings.local.php \
  apps/drupal/web/sites/default/settings.pantheon.php apps/drupal/web/sites/default/files/x.txt apps/drupal/private/x \
  apps/drupal/web/index.php apps/drupal/web/update.php apps/drupal/web/autoload.php apps/drupal/web/.htaccess \
  apps/drupal/web/robots.txt apps/drupal/web/web.config apps/drupal/web/sites/default/default.settings.php \
  apps/drupal/web/sites/default/default.services.yml apps/drupal/drush/Commands/contrib/x/x.php; do
  ckp "ignored: $p" ign "$p"; done
for p in apps/drupal/web/sites/default/settings.php apps/drupal/web/modules/custom/.gitkeep apps/drupal/composer.json \
  apps/drupal/composer.lock apps/drupal/pantheon.yml apps/drupal/config/sync/core.extension.yml .ddev/config.yaml \
  .ddev/commands/web/drupal-install .ddev/commands/host/quality apps/drupal/phpcs.xml.dist apps/drupal/phpstan.neon.dist; do
  ckp "NOT ignored (owned): $p" nign "$p"; done
ckp "no tracked file matches an ignore rule (apps/drupal, .ddev)" bash -c \
  "[[ -z \$(git ls-files -ci --exclude-standard -- apps/drupal .ddev) ]]"
ckp "no generated scaffold file is tracked" bash -c \
  "[[ -z \$(git ls-files apps/drupal | grep -E '^apps/drupal/web/(index|update|autoload)\.php\$|^apps/drupal/web/(\.htaccess|robots\.txt|web\.config)\$|default\.(settings\.php|services\.yml)\$' || true) ]]"
ckp "old rule apps/drupal/drush/contrib/ replaced by drush/Commands/contrib/" bash -c \
  "grep -qxF 'apps/drupal/drush/Commands/contrib/' .gitignore && ! grep -qxF 'apps/drupal/drush/contrib/' .gitignore"
ckp "apps/drupal/private/ is ignored in .gitignore" bash -c "grep -qE '^/?apps/drupal/private/?\$' .gitignore"

case_start TC-T05-10 "config/sync baseline from the minimal profile (AC4, KD-5, C6)"
ckp "config/sync holds a real export (at least 10 YAML files, not a stub)" bash -c "[[ \$(ls '$SYNC'/*.yml 2>/dev/null | wc -l) -ge 10 ]]"
ckp "core.extension.yml names profile minimal" yeq "$SYNC/core.extension.yml" profile minimal
ckp "core.extension.yml lists the system module" bash -c "python3 -I '$WORK/h.py' y '$SYNC/core.extension.yml' module | grep -q '\"system\"'"
ckp "no contrib or API modules yet (jsonapi, rest, simple_oauth, basic_auth: T09/T10)" allout "$SYNC/core.extension.yml" 'jsonapi|simple_oauth|^\s*rest:|basic_auth|consumers'
ckp "system.site.yml has a UUID" bash -c "python3 -I '$WORK/h.py' y '$SYNC/system.site.yml' uuid | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\$'"
ckp "system.site.yml site mail is example.com (RFC 2606)" bash -c "python3 -I '$WORK/h.py' y '$SYNC/system.site.yml' mail | grep -qE '@example\.com\$'"
ckp "system.site.yml name is Meridian" yeq "$SYNC/system.site.yml" name Meridian
no_secret_sync() { [[ -d "$SYNC" ]] || { echo "missing $SYNC"; return 1; }
  ! grep -rqiE 'hash_salt|BEGIN [A-Z ]*PRIVATE KEY' "$SYNC" || { echo "salt or private key found"; return 1; }
  local pw; pw=$(python3 -I "$WORK/h.py" y "$SYNC/system.mail.yml" mailer_dsn.password) || return 1
  [[ "$pw" == null || -z "$pw" || "$pw" == None ]] || { echo "mailer_dsn.password is set"; return 1; }; }
ckp "no hash salt or key in config/sync; system.mail mailer_dsn.password is null" no_secret_sync
ckp "no uuid-free system.site (UUID kept so --existing-config keeps site identity)" bash -c "grep -q '^uuid:' '$SYNC/system.site.yml'"

case_start TC-T05-11 "drupal-install command, static (AC2, KD-5)"
ckp "exists and is executable" bash -c "[[ -f '$DI' && -x '$DI' ]]"
ckp "header: ## Description, ## Usage with [--force], ## Example (DDEV command format)" allin "$DI" '^## Description' '^## Usage:.*drupal-install.*\[--force\]' '^## Example'
ckp "strict mode: set -euo pipefail" allin "$DI" 'set -euo pipefail'
ckp "runs composer install --no-interaction" allin "$DI" 'composer install.*--no-interaction'
ckp "one call does site install plus config import: site:install --existing-config" allin "$DI" 'site:install' '--existing-config'
ckp "installs the minimal profile or uses the config profile, as admin with an example.com mail" allin "$DI" '--account-name=admin' '--account-mail=admin@example\.com'
ckp "refuses (exit 1) when Drupal is already installed unless --force" allin "$DI" '--force' 'exit 1' 'already installed|already'
ckp "installed-check uses drush status bootstrap" allin "$DI" 'status.*bootstrap|bootstrap'
ckp "rebuilds cache and fails on config:status differences" allin "$DI" 'cache:rebuild|cr' 'config:status'
ckp "prints the next step: ddev drush uli" allin "$DI" 'ddev drush uli'
ckp "negative: no password argument and no hard-coded password" allout "$DI" '--account-pass' 'password\s*=\s*\S' '--db-url'
ckp "negative: not named like the drush command (ddev drupal-install, not site-install)" bash -c "[[ -f .ddev/commands/web/drupal-install && ! -e .ddev/commands/web/site-install ]]"

case_start TC-T05-12 "ddev quality activation: quality.sh and host command (C4, KD-6)"
ckp "quality.sh still names the three manifests (T04a invariant)" allin "$QS" 'apps/drupal/composer\.json' 'services/engine/pyproject\.toml' 'apps/web/package\.json'
ckp "quality.sh has component-drupal and component-drupal-tests steps" allin "$QS" 'component-drupal[^-]|component-drupal"' 'component-drupal-tests'
ckp "component-drupal-tests is keyed on apps/drupal/phpunit.xml.dist (SKIP until T09)" allin "$QS" 'apps/drupal/phpunit\.xml\.dist'
ckp "component-drupal runs composer validate, phpcs and phpstan" allin "$QS" 'composer validate' 'phpcs' 'phpstan'
ckp "tool version calls always run (missing tool is a FAIL)" allin "$QS" 'phpcs --version' 'phpstan --version'
ckp "any empty-tree guard cites T05 and the T09 removal" bash -c "! grep -q 'no custom PHP yet' '$QS' || grep -qE 'T05' '$QS'"
ckp "host quality defaults the runner: \${QUALITY_RUNNER:-ddev}" allin "$HQ" 'QUALITY_RUNNER:-ddev'
ckp "host quality still honours an explicit QUALITY_RUNNER=native (default, not forced)" bash -c "! grep -qE '^\s*(export\s+)?QUALITY_RUNNER=ddev\s*\$' '$HQ'"
ckp "scripts/quality.sh parses (bash -n)" bash -n "$QS"

case_start TC-T05-13 "runbook docs/runbooks/local-setup.md content (AC6, C7)"
ckp "runbook exists, non-empty" need_file "$RB"
ckp "follows the runbook template headings" allin "$RB" '^# Runbook' '^## When to use' '^## Prerequisites' '^## Steps' '^## Verification' '^## Rollback' '^## Escalation'
ckp "documents the commands: ddev start, ddev drupal-install, ddev drush uli" allin "$RB" 'ddev start' 'ddev drupal-install' 'ddev drush uli'
ckp "documents verification: ddev drush cex or config:status, ddev drush status, ddev composer validate, ddev quality" allin "$RB" 'drush (cex|config:status)|config:export' 'ddev drush status' 'ddev composer validate' 'ddev quality'
ckp "prerequisites: Docker, DDEV, git; clone on the WSL2 Linux filesystem, not /mnt/c" allin "$RB" 'docker' 'ddev' 'git' 'WSL2' '/mnt/c'
ckp "WSL2 HTTPS: mkcert -install" allin "$RB" 'mkcert'
ckp "host composer is not used (use ddev composer)" allin "$RB" 'ddev composer'
ckp "never apply Pantheon dashboard upstream updates" allin "$RB" 'upstream'
ckp "do not record the admin password; use ddev drush uli" allin "$RB" 'password'
ckp "reinstall path: ddev drupal-install --force, and what it destroys" allin "$RB" 'drupal-install --force'
ckp "clean-clone note: ddev stop --unlist meridian for a second clone" allin "$RB" 'stop --unlist'
ckp "rollback: ddev delete / ddev poweroff" allin "$RB" 'ddev delete|ddev poweroff'
ckp "no real credential or token pasted in the runbook" allout "$RB" 'sk-ant-|ghp_[A-Za-z0-9]{20}|BEGIN [A-Z ]*PRIVATE KEY'
ckp "negative: runbook does not tell people to run host composer or --no-verify" allout "$RB" '^\s*\$?\s*composer (install|update|require)' '--no-verify'

case_start TC-T05-14 "documentation updates (C5, scope list)"
ckp "runbooks index lists local-setup.md" allin docs/runbooks/README.md 'local-setup'
ckp ".ddev/README.md covers config.yaml, drupal-install and the default quality runner" allin .ddev/README.md 'config\.yaml' 'drupal-install' 'QUALITY_RUNNER|runner'
ckp "apps/drupal/README.md: layout, version table with URL and date, upstream reference, config workflow" allin "$ADR" 'composer\.json' 'https?://' '20[0-9]{2}-[0-9]{2}-[0-9]{2}' 'upstream' 'config:export|cex'
ver_rows() { need_file "$ADR" || return 1
  local r; for r in 'pantheon\.yml|php_version' 'mariadb|database' 'drush' 'drupal-integrations' 'ddev'; do
    grep -iE "^\|.*($r)" "$ADR" | grep -qE 'https?://|owner to verify' || { echo "version table lacks a sourced row: $r"; return 1; }; done; }
ckp "version table rows carry a source URL or 'owner to verify' (every verify item resolved)" ver_rows
ckp "CLAUDE.md Commands table lists ddev start, ddev drupal-install, ddev drush uli" allin CLAUDE.md 'ddev start' 'ddev drupal-install' 'ddev drush uli'
ckp "root README Getting started points to the runbook" allin README.md 'local-setup'
ckp "CODING_STANDARDS tool table: phpcs/coder/phpstan rows no longer say verify" bash -c \
  "grep -iE '^\|.*(code ?sniffer|phpcs|coder|phpstan)' docs/standards/CODING_STANDARDS.md | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' && ! grep -iE '^\|.*(code ?sniffer|phpcs|coder|phpstan)' docs/standards/CODING_STANDARDS.md | grep -qi 'verify'"
ckp "TRACEABILITY R-11 / FR-26 rows name the T05 evidence (filled at close)" bash -c "grep -E '^\| (R-11|FR-26) ' docs/TRACEABILITY.md | grep -q 'T05'"

case_start TC-T05-15 "no new environment variable, no secrets in changed files (C6, KD-8)"
env_unchanged() { local base; base=$(git merge-base HEAD main 2>/dev/null || true)
  [[ -n "$base" ]] || { echo "no merge base with main"; return 1; }
  # T05 adds none; earlier tasks on this stacked branch may. Compare against the parent of the first T05 impl commit.
  local first; first=$(git log --reverse --format=%H --grep='^T05: ' -- apps/drupal .ddev | head -1 || true)
  [[ -n "$first" ]] || { echo "no T05 implementation commit yet"; return 1; }
  git diff --quiet "$first^" HEAD -- .env.example || { echo ".env.example changed since the first T05 commit"; git diff --stat "$first^" HEAD -- .env.example; return 1; }; }
cka ".env.example unchanged by T05 commits" env_unchanged
ckp "no .env file tracked" bash -c "[[ -z \$(git ls-files | grep -E '(^|/)\.env\$' || true) ]]"
ckp "no secret-shaped strings in T05 files" bash -c \
  "t05() { git ls-files -co --exclude-standard -- apps/drupal .ddev '$RB' '$QS' | grep -v composer.lock; }; f=\$(t05); [[ -n \"\$f\" ]] && ! echo \"\$f\" | xargs grep -IEn 'BEGIN [A-Z ]*PRIVATE KEY|sk-ant-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20}|xox[bp]-[0-9A-Za-z-]{10}' "
if command -v gitleaks >/dev/null 2>&1; then
  ckp "gitleaks over the working tree" gitleaks detect --no-git --source . --no-banner --redact
else skip "gitleaks not on PATH: the pre-commit hook covers it (TC-T05-24)"; fi

case_start TC-T05-16 "simulation-only denylist (FR-11, ADR-0006, CLAUDE.md)"
BR='zerodha|kite ?connect|\bkite\b|kiteconnect|upstox|angel ?(one|broking)|groww|fyers|5paisa|dhanhq|\bdhan\b|alice ?blue|interactive ?brokers|ibkr|alpaca|icici ?direct|smartapi|kite\.trade|place[_ -]?order|order[_ -]?placement'
deny_files() { local f; f=$(t05_files); [[ -n "$f" ]] || { echo "no T05 files to scan yet"; return 1; }
  ! echo "$f" | xargs grep -IinE "$BR" 2>/dev/null || { echo "denylist hit in T05 files"; return 1; }; }
ckp "denylist scan over every new T05 file is clean (non-empty file set required)" deny_files
deny_lock() { need_file "$CL" || return 1
  python3 -I -c "
import json,re,sys
d=json.load(open(sys.argv[1]))
pat=re.compile(sys.argv[2],re.I)
names=[p['name'] for p in d.get('packages',[])+d.get('packages-dev',[])]
hits=[n for n in names if pat.search(n.replace('-',' ').replace('/',' '))]
print(len(names),'package names scanned')
if not names: sys.exit(1)
if hits: print('denylist package names:',hits); sys.exit(1)" "$CL" "$BR|broker|trading|ccxt"; }
ckp "composer.lock package names contain no broker, trading or order SDK" deny_lock
ckp "composer.lock source and dist URLs contain no trading host" bash -c \
  "[[ -s '$CL' ]] && ! grep -iE '\"(url|homepage)\"' '$CL' | grep -iE 'zerodha|kite\.trade|upstox|angelone|groww|fyers|5paisa|dhan\.co|interactivebrokers|alpaca\.markets'"
ckp "no composer.json 'require' of any non-Drupal-ecosystem trading package" bash -c "[[ -s '$CJ' ]] && ! grep -iE '$BR|broker' '$CJ'"
ckp ".ddev/config.yaml has no outbound host other than DDEV/Drupal tooling" bash -c "[[ -s '$DDEVCFG' ]] && ! grep -iE 'https?://' '$DDEVCFG' | grep -ivE 'ddev\.(com|readthedocs|site)|drupal\.org|pantheon\.io|github\.com'"

case_start TC-T05-17 "naming (C-criteria, section 0)"
ckp "scripts/check-names.sh passes" scripts/check-names.sh
ckp ".ddev/config.yaml name is exactly meridian (not a placeholder name)" yeq "$DDEVCFG" name meridian
ckp "composer name uses the meridian vendor" jeq "$CJ" name meridian/drupal
ckp "no old placeholder names in T05 files (case-insensitive)" bash -c \
  "f=\$(git ls-files -co --exclude-standard -- apps/drupal .ddev '$RB'); [[ -n \"\$f\" ]] && ! echo \"\$f\" | grep -v composer.lock | xargs grep -IinE 'trading''-agent|trading''_engine|trading''_ingest'"

case_start TC-T05-18 "shell hygiene of the new command (C4, standards: Shell)"
ckp "drupal-install parses (bash -n)" bash -n "$DI"
ckp "drupal-install has a bash shebang" bash -c "head -1 '$DI' | grep -qE '^#!/(usr/)?bin/(env )?bash'"
if command -v shellcheck >/dev/null 2>&1; then
  ckp "shellcheck drupal-install" shellcheck -s bash "$DI"
  ckp "shellcheck scripts/quality.sh and .ddev/commands/host/quality" shellcheck -s bash "$QS" "$HQ"
else skip "shellcheck not installed: the pre-commit shellcheck hook covers it (TC-T05-24)"; fi
ckp "drupal-install quotes variables (no bare \$VAR in test brackets)" bash -c "! grep -nE '\[ +\\\$[A-Za-z_]+ +(=|-eq)' '$DI'"

case_start TC-T05-19 "empty custom tree and PHP tooling configs (KD-6)"
ckp "web/modules/custom/.gitkeep tracked (phpcs/PHPStan path exists)" bash -c "git ls-files --error-unmatch apps/drupal/web/modules/custom/.gitkeep >/dev/null"
ckp "phpcs.xml.dist and phpstan.neon.dist unchanged in scope: level 6, no baseline, ignores need comments" allin apps/drupal/phpstan.neon.dist 'level:\s*6' 'reportIgnoresWithoutComments:\s*true'
ckp "phpstan.neon.dist has no baseline" allout apps/drupal/phpstan.neon.dist 'baseline'
ckp "phpstan config loads phpstan-drupal (explicit include or extension-installer comment)" allin apps/drupal/phpstan.neon.dist 'phpstan-drupal|extension-installer'
cka "phpunit.xml.dist is absent until T09 (the SKIP is visible, T05 does not add it)" bash -c "[[ ! -e apps/drupal/phpunit.xml.dist ]]"
cka "no custom module exists yet (T09)" bash -c "[[ -z \$(git ls-files 'apps/drupal/web/modules/custom/*' | grep -v '\.gitkeep\$' || true) ]]"

case_start TC-T05-20 "composer.lock size vs check-added-large-files (KD-7)"
lock_size() { need_file "$CL" || return 1; local kb; kb=$(( ($(stat -c %s "$CL") + 1023) / 1024 ))
  if [[ $kb -le 1024 ]]; then echo "lock is ${kb} KB, under the 1024 KB limit"; return 0; fi
  grep -n 'composer.lock' .pre-commit-config.yaml | grep -q . || { echo "lock is ${kb} KB, over 1024 KB, and not excluded"; return 1; }
  grep -B2 -A2 'composer.lock' .pre-commit-config.yaml | grep -q 'T05' || { echo "exclusion lacks a T05 ticket comment"; return 1; }
  grep -E 'maxkb' .pre-commit-config.yaml | grep -q '1024' || { echo "global limit was changed"; return 1; }; }
ckp "lock under 1024 KB, or narrowly excluded with a T05 comment and the global limit unchanged" lock_size

case_start TC-T05-21 "T04a regression suite still green (C4)"
ckp "T04a run-checks.sh --regression exits 0 (no invariant regression)" bash -c "docs/tests/T04a/run-checks.sh --regression >'$WORK/t04a.txt' 2>&1 || { grep -E '^\s+FAIL' '$WORK/t04a.txt' | head -8; exit 1; }"
ckp "T03 and T04 regression sets exit 0" bash -c "for t in T03 T04; do if docs/tests/\$t/run-checks.sh --regression >'$WORK/r.txt' 2>&1; then :; else echo \"\$t regression failed\"; grep -E '^\s+FAIL' '$WORK/r.txt' | head -5; exit 1; fi; done"

case_start TC-T05-22 "only example.com addresses in T05 files (KD-5, no real mailbox)"
emails() { local f out; f=$(t05_files); [[ -n "$f" ]] || { echo "no T05 files"; return 1; }
  out=$(echo "$f" | xargs grep -IohE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 2>/dev/null | sort -u \
    | grep -vE '@(example\.(com|org|net)|github\.com|users\.noreply\.github\.com)$' || true)
  [[ -z "$out" ]] || { echo "non-example addresses: $out"; return 1; }; }
ckp "every e-mail address in T05 files is example.com/org/net (or github.com for git remotes)" emails
ckp "drupal-install uses admin@example.com for site and account mail" allin "$DI" 'admin@example\.com'

case_start TC-T05-23 "scope discipline: no extra services, no deploy config (non-goals)"
cka "no docker-compose or extra DDEV services added (T06)" bash -c "[[ -z \$(git ls-files .ddev | grep -E 'docker-compose\.[a-z_-]+\.yaml' || true) ]]"
ckp "no providers/pantheon.yaml and no deploy-drupal workflow content (T07)" bash -c "[[ ! -e .ddev/providers/pantheon.yaml ]]"
ckp "no ci.yml Drupal job added (T08)" bash -c "[[ ! -e .github/workflows/ci.yml ]] || ! grep -qi 'ddev' .github/workflows/ci.yml"
cka "no ddev engine/pg/next/e2e commands (T06)" bash -c "[[ -z \$(ls .ddev/commands/web .ddev/commands/host 2>/dev/null | grep -E '^(engine|pg|next|e2e)\$' || true) ]]"
cka "only the planned DDEV commands under .ddev/commands" bash -c \
  "ls .ddev/commands/*/ | grep -vE '^(\.\.?|.*:|)\$' | grep -vE '^(drupal-install|quality|README\.txt|\.gitattributes|\.gitignore|README\.md)\$' | grep -q . && { echo 'unplanned command files:'; ls .ddev/commands/*/; exit 1; } || exit 0"

case_start TC-T05-24 "pre-commit hooks over the T05 changes (C4)"
PC=.tools/pre-commit
if [[ -x "$PC" ]]; then
  ckp "pre-commit run --all-files exits 0" "$PC" run --all-files
else skip ".tools/pre-commit not bootstrapped: run scripts/bootstrap-dev.sh (owner/network)"; fi

fi   # static

# =====================================================================================================
have_ddev() { command -v ddev >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
dd() { ddev "$@"; }   # indirection to keep checks readable

db_match() {   # VERSION() PANTHEON_VERSION: MariaDB reports e.g. 10.6.21-MariaDB
  [[ -n "$2" && "$1" == "$2".* && "$1" == *[Mm]aria* ]] || { echo "db version '$1' vs '$2'"; return 1; }; }
live_checks() {   # runs in the current directory, which must be the project root
  if ! have_ddev; then
    for id in 25:"ddev exec php / mysql versions" 26:"ddev describe healthy" 27:"ddev composer validate" 28:"ddev drush status" \
      29:"ddev drupal-install --force" 30:"drupal-install refuses without --force" 31:"ddev drush uli logs in" \
      32:"cex no diff" 33:"git status clean after install + cex" 34:"ddev quality exit 0" 35:"ddev quality rejects a violation" 36:"ddev composer audit"; do
      case_start "TC-T05-${id%%:*}" "${id#*:} (live)"
      blk "ddev and/or a Docker daemon not available in this environment: owner-run (T05_CONFIRM not needed)"
    done
    return 0
  fi
  if [[ ! -f .ddev/config.yaml || ! -f apps/drupal/composer.json || ! -f "$DI" ]]; then
    local id
    for id in 25:"live PHP and DB versions" 26:"live web and db healthy" 27:"ddev composer validate" 28:"ddev drush status" \
      29:"ddev drupal-install --force" 30:"drupal-install refuses without --force" 31:"ddev drush uli logs in" \
      32:"cex no diff" 33:"git status clean after install + cex" 34:"ddev quality exit 0" 35:"ddev quality rejects a violation" 36:"ddev composer audit"; do
      case_start "TC-T05-${id%%:*}" "${id#*:} (live)"
      ran=$((ran+1)); bad "implementation missing (.ddev/config.yaml, apps/drupal/composer.json or $DI): nothing to run"
    done
    return 0
  fi
  local out rc cfgphp cfgdb phpv dbv url jar cfgdiff

  case_start TC-T05-25 "live PHP and database versions equal pantheon.yml (AC3)"
  cfgphp=$(yget "$PANT" php_version 2>/dev/null || echo "?"); cfgdb=$(yget "$PANT" database.version 2>/dev/null || echo "?")
  phpv=$(ddev exec php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>&1 | tail -1) || true
  dbv=$(ddev mysql -N -e 'SELECT VERSION()' 2>&1 | tail -1) || true
  ckp "ddev PHP '$phpv' == pantheon php_version '$cfgphp'" eq "$phpv" "$cfgphp" php
  ckp "ddev DB '$dbv' starts with pantheon database.version '$cfgdb' and is MariaDB" db_match "$dbv" "$cfgdb"

  case_start TC-T05-26 "live: web and db healthy (AC1)"
  ckp "ddev describe lists web and db as OK/running" bash -c "ddev describe -j | python3 -I -c \"
import json,sys
r=json.load(sys.stdin)['raw']
st={s:r['services'][s]['status'] for s in ('web','db')}
print(st); sys.exit(0 if all(v=='running' for v in st.values()) else 1)\""
  ckp "project name is meridian and URL is https://meridian.ddev.site" bash -c "ddev describe -j | grep -q 'https://meridian.ddev.site'"

  case_start TC-T05-27 "live: ddev composer validate (AC5)"
  ckp "ddev composer validate exits 0" ddev composer validate --no-check-publish
  ckp "ddev composer validate --check-lock (lock matches composer.json)" ddev composer validate --no-check-publish --check-lock
  ckp "composer install is a no-op when vendor is current (post-start hook idempotent)" bash -c "ddev composer install --no-interaction 2>&1 | grep -qiE 'Nothing to install|Nothing to install, update or remove'"

  case_start TC-T05-28 "live: ddev drush status (AC5)"
  ckp "ddev drush status exits 0, Drupal bootstrap Successful, database Connected" bash -c \
    "o=\$(ddev drush status --format=json) && python3 -I -c \"
import json,sys
d=json.loads(sys.argv[1]); print(d.get('bootstrap'), d.get('db-status'))
sys.exit(0 if d.get('bootstrap')=='Successful' and d.get('db-status')=='Connected' else 1)\" \"\$o\""
  ckp "config-sync resolves to apps/drupal/config/sync" bash -c "ddev drush status --field=config-sync | grep -q 'config/sync'"
  ckp "drush comes from vendor (apps/drupal/vendor/bin/drush)" bash -c "ddev exec -d /var/www/html/apps/drupal test -x vendor/bin/drush"

  case_start TC-T05-29 "live: one documented install command, --force (AC2)"
  ckp "ddev drupal-install --force exits 0" bash -c "ddev drupal-install --force >'$WORK/inst.txt' 2>&1 || { tail -15 '$WORK/inst.txt'; exit 1; }"
  ckp "output points at ddev drush uli" bash -c "grep -q 'ddev drush uli' '$WORK/inst.txt'"
  ckp "site is installed from the minimal profile with the committed UUID" bash -c \
    "u=\$(python3 -I '$WORK/h.py' y '$SYNC/system.site.yml' uuid); [[ -n \$u && \$(ddev drush config:get system.site uuid --format=string) == \"\$u\" ]]"
  ckp "profile is minimal" bash -c "ddev drush status --field=install-profile | grep -qx minimal || ddev drush status --field=install-profile | grep -q minimal"

  case_start TC-T05-30 "live negative: second drupal-install without --force refuses and leaves the site intact (AC2)"
  local before after
  before=$(ddev drush sqlq 'SELECT COUNT(*) FROM users' 2>/dev/null | tail -1 || echo "?")
  out=$(ddev drupal-install 2>&1) && rc=0 || rc=$?
  if [[ $rc -ne 0 ]]; then pass "exit code is non-zero ($rc) without --force"; else bad "exit code was 0 without --force"; fi
  ran=$((ran+1))
  if grep -qiE 'already|--force' <<<"$out"; then pass "message explains the refusal and names --force"; else bad "no explanatory message"; show_out "$out"; fi
  ran=$((ran+1))
  after=$(ddev drush sqlq 'SELECT COUNT(*) FROM users' 2>/dev/null | tail -1 || echo "?")
  ckp "site intact: users table row count unchanged ($before -> $after) and bootstrap still Successful" bash -c \
    "[[ '$before' == '$after' && '$before' != '?' ]] && ddev drush status --field=bootstrap | grep -q Successful"

  case_start TC-T05-31 "live: ddev drush uli logs in as admin (AC2)"
  url=$(ddev drush uli --no-browser 2>/dev/null | tail -1 || true)
  ckp "uli prints https://meridian.ddev.site/user/reset/... URL" bash -c "[[ '$url' =~ ^https://meridian\.ddev\.site/user/reset/[0-9]+/ ]]"
  jar="$WORK/cj.txt"
  ckp "following the link with curl -k -L (cookie jar) reaches a logged-in page" bash -c \
    "curl -ksL -c '$jar' -b '$jar' --max-time 60 -o '$WORK/login1.html' '$url' && curl -ksL -c '$jar' -b '$jar' --max-time 60 -o '$WORK/me.html' https://meridian.ddev.site/user && grep -qiE 'Log out|user/logout|admin' '$WORK/me.html' && ! grep -qiE 'name=\"pass\"' '$WORK/me.html'"
  ckp "negative: a garbage reset token is refused (no session)" bash -c \
    "c=\$(curl -ks --max-time 60 -o /dev/null -w '%{http_code}' https://meridian.ddev.site/user/reset/1/0/bogus); [[ \$c == 403 || \$c == 302 || \$c == 200 ]] && ! curl -ksL --max-time 60 https://meridian.ddev.site/user/reset/1/0/bogus | grep -qi 'user/logout'"

  case_start TC-T05-32 "live: cex after a fresh install produces no diff (AC4)"
  ckp "ddev drush config:status reports no differences" bash -c "o=\$(ddev drush config:status 2>&1); echo \"\$o\"; grep -qiE 'No differences' <<<\"\$o\""
  ckp "ddev drush cex -y exits 0 and says nothing to export" bash -c "o=\$(ddev drush config:export -y 2>&1); echo \"\$o\"; grep -qiE 'no differences|nothing to export|The active configuration is identical' <<<\"\$o\""
  cfgdiff=$(git status --porcelain -- apps/drupal/config/sync)
  ckp "git status --porcelain apps/drupal/config/sync is empty" eq "$cfgdiff" "" "config/sync diff"
  ckp "negative control: a config change shows up in cex (harness proves detection), then is reverted" bash -c "
    ddev drush config:set system.site name 'T05 probe' -y >/dev/null 2>&1
    d=\$(ddev drush config:status 2>&1 | grep -ci 'only in DB\|different')
    ddev drush config:import -y >/dev/null 2>&1
    n=\$(ddev drush config:get system.site name --format=string)
    [[ \$d -ge 1 && \$n == Meridian ]]"

  case_start TC-T05-33 "live: git status clean after start, install and cex (KD-7 invariant)"
  ckp "git status --porcelain is empty for the whole repository" bash -c "o=\$(git status --porcelain); echo \"\$o\"; [[ -z \"\$o\" ]]"
  ckp "settings.php unchanged by DDEV (git diff --quiet)" git diff --quiet -- "$SET"

  case_start TC-T05-34 "live: ddev quality exits 0; component-drupal PASS, tests SKIP (C4, TC-T04a-48)"
  out=$(ddev quality 2>&1) && rc=0 || rc=$?
  printf '%s\n' "$out" >"$WORK/q.txt"
  if [[ $rc -eq 0 ]]; then pass "ddev quality exit 0"; else bad "ddev quality exit $rc"; show_out "$(tail -15 <<<"$out")"; fi
  ran=$((ran+1))
  ckp "PASS line for component-drupal" bash -c "grep -E '^\s*PASS\s+component-drupal\b' '$WORK/q.txt' | grep -qv 'tests'"
  ckp "visible SKIP for component-drupal-tests (no apps/drupal/phpunit.xml.dist)" bash -c "grep -E '^\s*SKIP\s+component-drupal-tests' '$WORK/q.txt' | grep -q 'phpunit.xml.dist'"
  ckp "no FAIL line anywhere" bash -c "[[ -s '$WORK/q.txt' ]] && ! grep -E '^\s*FAIL' '$WORK/q.txt'"

  case_start TC-T05-35 "live negative: a PHP style/type violation makes ddev quality fail (TC-T04a-49)"
  local bad_php=apps/drupal/web/modules/custom/zz_t05_probe.php
  mkdir -p "$(dirname "$bad_php")"
  printf '<?php\nclass bad_class{function X(){ return 1;}}\n' >"$bad_php"
  out=$(ddev quality 2>&1) && rc=0 || rc=$?
  rm -f "$bad_php"
  if [[ $rc -ne 0 ]]; then pass "ddev quality exits non-zero with a violating custom PHP file (rc=$rc)"; else bad "violating file passed ddev quality"; fi
  ran=$((ran+1))
  if grep -qE 'FAIL\s+component-drupal\b' <<<"$out"; then pass "FAIL line names component-drupal"; else bad "no FAIL component-drupal line"; show_out "$(tail -10 <<<"$out")"; fi
  ran=$((ran+1))
  ckp "probe file removed; working tree clean again" bash -c "[[ ! -e '$bad_php' && -z \$(git status --porcelain) ]]"

  case_start TC-T05-36 "live: ddev composer audit recorded, no high or critical advisory (plan DoD)"
  out=$(ddev composer audit --no-interaction 2>&1) && rc=0 || rc=$?
  emit "        audit exit code: $rc"
  if [[ $rc -eq 0 ]]; then pass "composer audit exit 0 (no advisories)"
  elif grep -qiE 'network|could not resolve|curl error|unable to' <<<"$out"; then blk "composer audit could not reach the advisory database (network)"; show_out "$out"
  elif grep -qiE 'Severity: *(high|critical)' <<<"$out"; then bad "high or critical advisory present"; show_out "$out"
  else pass "advisories present but none high or critical (listed in evidence)"; show_out "$out"; fi
  ran=$((ran+1))
}

# =====================================================================================================
clean_clone() {
  case_start TC-T05-37 "clean clone: ddev start without manual steps (AC1, C7)"
  if [[ "${T05_CONFIRM:-0}" != 1 ]]; then
    blk "destructive to the local DDEV registration (ddev stop --unlist meridian); re-run with T05_CONFIRM=1"
    case_start TC-T05-38 "clean clone: install, cex, git status (AC2, AC4, KD-7)"; blk "needs TC-T05-37 (T05_CONFIRM=1)"
    return 0
  fi
  if ! have_ddev; then
    blk "ddev and/or Docker not available: owner-run"
    case_start TC-T05-38 "clean clone: install, cex, git status (AC2, AC4, KD-7)"; blk "needs DDEV"
    return 0
  fi
  local scratch br t0 t1 out rc
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/t05clone.XXXXXX"); br=$(git rev-parse --abbrev-ref HEAD)
  ddev stop --unlist meridian >/dev/null 2>&1 || true
  # a fresh machine has no database volume; the volume of the previous checkout survives an unlist
  ddev delete -Oy meridian >/dev/null 2>&1 || true
  if ! git clone -q --branch "$br" "file://$ROOT" "$scratch/meridian" 2>&1; then
    bad "git clone of $br failed"; return 0; fi
  ran=$((ran+1))
  # a clone carries only committed files: uncommitted T05 deliverables are not tested, and are flagged here.
  if [[ -n "$(git status --porcelain -- apps/drupal .ddev scripts/quality.sh docs/runbooks CLAUDE.md README.md)" ]]; then bad "source tree has uncommitted changes: the clone does not contain them"; ran=$((ran+1)); fi
  cd "$scratch/meridian"
  t0=$(date +%s)
  out=$(ddev start 2>&1) && rc=0 || rc=$?
  t1=$(date +%s); emit "        ddev start took $((t1-t0)) s (NFR-17 data point)"
  ran=$((ran+1))
  if [[ $rc -eq 0 ]]; then pass "ddev start exit 0 on a fresh clone with no manual steps"; else bad "ddev start exit $rc"; show_out "$(tail -15 <<<"$out")"; fi
  ckp "git status --porcelain empty after ddev start (DDEV wrote no tracked change)" bash -c "o=\$(git status --porcelain); echo \"\$o\"; [[ -z \"\$o\" ]]"
  ckp "ddev drush status works straight after start (post-start composer install ran)" bash -c "ddev drush status --field=drupal-version | grep -qE '^11\.'"

  case_start TC-T05-38 "clean clone: first install without --force, cex, git status (AC2, AC4, KD-7)"
  t0=$(date +%s)
  out=$(ddev drupal-install 2>&1) && rc=0 || rc=$?
  t1=$(date +%s); emit "        ddev drupal-install took $((t1-t0)) s"
  ran=$((ran+1))
  if [[ $rc -eq 0 ]]; then pass "ddev drupal-install exit 0 on an empty database (no --force needed)"; else bad "install exit $rc"; show_out "$(tail -15 <<<"$out")"; fi
  ckp "ddev drush cex -y leaves apps/drupal/config/sync untouched" bash -c "ddev drush config:export -y >/dev/null 2>&1; [[ -z \$(git status --porcelain -- apps/drupal/config/sync) ]]"
  ckp "git status --porcelain is empty for the whole clone (KD-7 invariant)" bash -c "o=\$(git status --porcelain); echo \"\$o\"; [[ -z \"\$o\" ]]"
  ckp "ddev drush uli prints the meridian.ddev.site reset URL" bash -c "ddev drush uli --no-browser | tail -1 | grep -qE '^https://meridian\.ddev\.site/user/reset/'"
  emit "  --- live checks inside the clone ---"
  live_checks
  ddev delete -Oy meridian >/dev/null 2>&1 || true
  cd "$ROOT"; rm -rf "$scratch"
  ddev start >/dev/null 2>&1 || emit "  NOTE: could not restart the original working project; run 'ddev start' in $ROOT"
}

case "$MODE" in
  live|liveonly) live_checks ;;
  clone) clean_clone ;;
esac

# =====================================================================================================
if [[ "$MODE" != reg ]]; then
case_start TC-T05-39 "AC6: runbook followed verbatim on a clean machine or container (owner-run)"
blk "owner-run (or tester with a fresh container): follow docs/runbooks/local-setup.md word for word and record each command, output and the total time; not automatable"
case_start TC-T05-40 "WSL2 browser login over HTTPS with mkcert (owner-run)"
blk "owner-run: open the ddev drush uli URL in a Windows browser; confirm no certificate warning after the runbook's mkcert step"
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
echo "SUMMARY: mode=$MODE cases: $pc PASS, $fc FAIL, $bc BLOCKED; checks executed: $ran; SKIP (optional tools): $skipped; BLOCKED lines: $blocked"
if [[ $fail -eq 0 ]]; then echo "RESULT: ALL EXECUTED CHECKS PASSED ($bc case(s) blocked)"; else echo "RESULT: ONE OR MORE CHECKS FAILED"; fi
exit "$fail"
