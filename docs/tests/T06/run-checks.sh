#!/usr/bin/env bash
# Automated checks for T06 (extra Docker services in DDEV). Designed from the acceptance criteria in
# docs/TASKS.md, the approved plan docs/tasks/T06/plan.md (KD-1 to KD-11, "Test hooks needed"),
# docs/tasks/T06/decision-nextjs-placeholder.md and the common criteria C1 to C7, NOT from the
# implementation. Failing before the implementation exists is expected.
#
# Usage:
#   docs/tests/T06/run-checks.sh                static checks, TC-T06-01 to 19 (no network, no DDEV)
#   docs/tests/T06/run-checks.sh --regression   invariant static checks only (CI PR set, decision D-5)
#   docs/tests/T06/run-checks.sh --live          static checks, then live checks TC-T06-20 to 43 against
#                                                the running project in this working tree (needs DDEV,
#                                                Docker, network; it stops and restarts services, runs
#                                                ddev restart and ddev poweroff, and writes test tables
#                                                t06_* to the local Postgres, which it drops again)
#   docs/tests/T06/run-checks.sh --live-only     live checks only
#   T06_CONFIRM=1 docs/tests/T06/run-checks.sh --clean-clone
#                                                TC-T06-44 to 47 in a fresh clone in a scratch dir, with no
#                                                .env. Runs `ddev stop --unlist meridian` first and restarts
#                                                this working tree at the end; needs T06_CONFIRM=1.
#   Environment:
#     T06_EVIDENCE=1  also writes each case's lines to docs/tests/T06/evidence/TC-T06-nn.<UTC run id>.txt.
#                     The run id makes every filename new, so a rerun never overwrites earlier evidence.
#     T06_CONFIRM=1   required for --clean-clone.
#     T06_BASE=SHA    commit that snapshot checks compare against (default 6e9e69d, the T06 branch point).
#
# Output: one line per check (PASS / FAIL / BLOCKED / SKIP), one roll-up line per case, then a summary.
# Exit status is 1 if any check FAILs, else 0. A missing file makes every dependent check FAIL (no vacuous
# pass). SKIP is only for optional host tools (shellcheck, pre-commit, gitleaks), counted and printed.
# BLOCKED means the case cannot run here (no DDEV, no network, owner-run, or accepted deferral); it is not
# a pass, does not change the exit status, and the report must list each one.
#
# Tags (decision D-5): ckp = invariant (runs in all static modes); cka = snapshot, true only at the close
# of T06 (for example "no apps/web/package.json" until T21); skipped by --regression, count printed.
# shellcheck disable=SC2329,SC2015,SC2016,SC2034 # T06: check helpers are called through ckp/cka by name; regexes are literal
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel) || exit 2
cd "$ROOT"
T=docs/tests/T06
EVD=$ROOT/$T/evidence
RUNID=$(date -u +%Y%m%dT%H%M%SZ)
BASE=${T06_BASE:-6e9e69d}

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
CASE=""; CASE_FAIL=0; EVFILE=""
declare -a ORDER=()
declare -A CSTAT=()
declare -A NPASS=()

emit() {
  printf '%s\n' "$1"
  if [[ "${T06_EVIDENCE:-0}" == 1 && -n "$EVFILE" ]]; then printf '%s\n' "$1" >>"$EVFILE"; fi
}
case_start() {   # ID TITLE
  CASE=$1; CASE_FAIL=0; ORDER+=("$1"); CSTAT["$1"]=PASS; NPASS["$1"]=0
  if [[ "${T06_EVIDENCE:-0}" == 1 ]]; then mkdir -p "$EVD"; EVFILE="$EVD/$1.$RUNID.txt"; : >"$EVFILE"; fi
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

WORK=$(mktemp -d "${TMPDIR:-/tmp}/t06.XXXXXX")
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
# rcof CMD...: run with stdin closed; sets RC and OUT (stdout and stderr merged)
RC=0; OUT=""; export RC OUT
rcof() { OUT=$("$@" 2>&1 </dev/null) && RC=0 || RC=$?; }

# ---------- file names ----------
CPG=.ddev/docker-compose.postgres.yaml
CEN=.ddev/docker-compose.engine.yaml
CWB=.ddev/docker-compose.next.yaml
CMDD=.ddev/commands/host
CENG=$CMDD/engine
CNEXT=$CMDD/next
CPGC=$CMDD/pg
CSTAT_CMD=$CMDD/meridian-status
EPT=.ddev/meridian-engine/entrypoint.sh
WST=.ddev/meridian-web/start.sh
WPH=.ddev/meridian-web/placeholder-server.mjs
RB=docs/runbooks/local-setup.md
DR=.ddev/README.md
PLACEHOLDER='meridian-web placeholder; the dashboard arrives in T21'

# container names (container_name pattern ddev-${DDEV_SITENAME}-<service>; DDEV's own are ddev-<site>-web/db)
C_WEB=ddev-meridian-web
C_DB=ddev-meridian-db
C_PG=ddev-meridian-meridian-postgres
C_EN=ddev-meridian-meridian-engine
C_WB=ddev-meridian-meridian-web
FIVE=("$C_WEB" "$C_DB" "$C_PG" "$C_EN" "$C_WB")

t06_files() {   # files T06 adds or changes, relative to the branch point (plus untracked)
  { git diff --name-only "$BASE" -- . 2>/dev/null; git ls-files -o --exclude-standard; } | sort -u \
    | grep -vE '^docs/tests/(T0[0-5]|T04a)/|^docs/tasks/|^docs/PROGRESS|^docs/TRACEABILITY|^docs/tests/T06/evidence/' || true
}
t06_impl_files() {   # implementation files only (not tests, not docs)
  ls "$CPG" "$CEN" "$CWB" "$CENG" "$CNEXT" "$CPGC" "$CSTAT_CMD" "$EPT" "$WST" "$WPH" 2>/dev/null || true
}

# ---------- python helper: parse and check the three compose files ----------
cat >"$WORK/cc.py" <<'PY'
import json, re, sys
try:
    import yaml
except Exception as exc:
    print("PyYAML missing:", exc); sys.exit(3)

FILES = {"postgres": (".ddev/docker-compose.postgres.yaml", "meridian-postgres"),
         "engine": (".ddev/docker-compose.engine.yaml", "meridian-engine"),
         "next": (".ddev/docker-compose.next.yaml", "meridian-web")}
problems = []

def load(kind):
    path, svc = FILES[kind]
    try:
        with open(path, encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
    except Exception as exc:
        problems.append(f"{path}: cannot read or parse: {exc}"); return None, None, {}
    if not isinstance(data, dict) or "services" not in data:
        problems.append(f"{path}: no services key"); return data, None, {}
    s = data["services"].get(svc)
    if s is None:
        problems.append(f"{path}: service '{svc}' missing (found {list(data['services'])})"); return data, None, {}
    return data, svc, s

def kv(x):
    if x is None: return {}
    if isinstance(x, dict): return {str(k): ("" if v is None else str(v)) for k, v in x.items()}
    out = {}
    for item in x:
        k, _, v = str(item).partition("=")
        if not _:
            k, _, v = str(item).partition(": ")
        out[k.strip()] = v.strip()
    return out

def flat(x): return json.dumps(x, sort_keys=True)

def check(name):
    for kind in FILES:
        data, svc, s = load(kind)
        if svc is None: continue
        path = FILES[kind][0]
        if name == "names":
            if list(data["services"]) != [svc]: problems.append(f"{path}: services are {list(data['services'])}, want only {svc}")
            want = "ddev-${DDEV_SITENAME}-" + svc
            if s.get("container_name") != want: problems.append(f"{path}: container_name {s.get('container_name')!r}, want {want!r}")
            lab = kv(s.get("labels"))
            if lab.get("com.ddev.site-name") != "${DDEV_SITENAME}": problems.append(f"{path}: label com.ddev.site-name is {lab.get('com.ddev.site-name')!r}")
            if lab.get("com.ddev.approot") != "${DDEV_APPROOT}": problems.append(f"{path}: label com.ddev.approot is {lab.get('com.ddev.approot')!r}")
        elif name == "images":
            img = str(s.get("image", ""))
            pats = {"postgres": r"^postgres:16(\.[0-9]+)+-[a-z0-9.-]+@sha256:[0-9a-f]{64}$",
                    "engine": r"^python:3\.12\.[0-9]+-slim-[a-z0-9.-]+@sha256:[0-9a-f]{64}$",
                    "next": r"^node:22\.[0-9]+\.[0-9]+-[a-z0-9.-]+@sha256:[0-9a-f]{64}$"}
            if not re.match(pats[kind], img): problems.append(f"{path}: image {img!r} does not match {pats[kind]}")
            if "latest" in img: problems.append(f"{path}: latest in image")
            if "build" in s: problems.append(f"{path}: build: present (T13/T21 own Dockerfiles)")
        elif name == "health":
            h = s.get("healthcheck")
            if not h or not h.get("test"): problems.append(f"{path}: no healthcheck.test"); continue
            for k in ("interval", "timeout", "retries", "start_period"):
                if k not in h: problems.append(f"{path}: healthcheck.{k} missing")
            t = flat(h["test"])
            if kind == "postgres":
                for p in ("pg_isready", "meridian", "127.0.0.1"):
                    if p not in t: problems.append(f"{path}: health test lacks {p}")
                if str(h.get("retries")) != "12": problems.append(f"{path}: retries {h.get('retries')}, want 12")
            if kind == "engine":
                if "python3" not in t or "meridian-ca-bundle" not in t: problems.append(f"{path}: health test should be python3 -c on the CA bundle")
            if kind == "next":
                if "fetch" not in t or "127.0.0.1:3000" not in t: problems.append(f"{path}: health test should fetch http://127.0.0.1:3000/")
                if not str(h.get("start_period")).startswith("120"): problems.append(f"{path}: start_period {h.get('start_period')}, want 120s")
            if kind in ("engine", "next"):
                for p in ("meridian-postgres", "meridian.ddev.site", "DRUPAL", "5432"):
                    if p in t: problems.append(f"{path}: health check must not depend on {p} (no cascading unhealthy)")
        elif name == "envfile":
            ef = s.get("env_file")
            if not isinstance(ef, list) or len(ef) < 2: problems.append(f"{path}: env_file must list .env.example then .env"); continue
            def norm(e):
                return (e, True) if isinstance(e, str) else (e.get("path", ""), e.get("required", True))
            (p0, r0), (p1, r1) = norm(ef[0]), norm(ef[1])
            if not (p0.startswith("${DDEV_APPROOT}/") and p0.endswith("/.env.example")) or r0 is False: problems.append(f"{path}: env_file[0] is {ef[0]!r}, want required ${{DDEV_APPROOT}}/.env.example")
            if not (p1.startswith("${DDEV_APPROOT}/") and p1.endswith("/.env")) or r1 is not False: problems.append(f"{path}: env_file[1] is {ef[1]!r}, want ${{DDEV_APPROOT}}/.env with required: false")
            if len(ef) != 2: problems.append(f"{path}: env_file has {len(ef)} entries, want exactly 2")
        elif name == "plain":
            for k in ("ports", "restart"):
                if k in s: problems.append(f"{path}: {k}: present ({s[k]!r})")
            net = s.get("networks")
            if net is not None and not ({"default", "ddev_default"} <= set(net)): problems.append(f"{path}: networks {net!r} must include default and ddev_default")
            env = kv(s.get("environment"))
            for k, v in env.items():
                if re.search(r"(PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE)", k, re.I) and v and not v.startswith("${") and "$" not in v:
                    problems.append(f"{path}: environment {k} holds a literal value")
            txt = open(path, encoding="utf-8").read()
            if "change-me" in txt: problems.append(f"{path}: contains the .env.example placeholder value")
            if kind != "postgres":
                if str(s.get("user")) != "${DDEV_UID}:${DDEV_GID}": problems.append(f"{path}: user {s.get('user')!r}, want ${{DDEV_UID}}:${{DDEV_GID}}")
                if env.get("HOME") != "/tmp": problems.append(f"{path}: HOME is {env.get('HOME')!r}, want /tmp")
                vols = flat(s.get("volumes"))
                if "${DDEV_APPROOT}" not in vols or "/var/www/html" not in vols: problems.append(f"{path}: repo bind mount ${{DDEV_APPROOT}}:/var/www/html missing")
        elif name == "router":
            env = kv(s.get("environment"))
            vols = flat(s.get("volumes"))
            if kind in ("engine", "next"):
                if "ddev-router:meridian.ddev.site" not in flat(s.get("external_links")): problems.append(f"{path}: external_links lacks ddev-router:meridian.ddev.site")
                if "ddev-global-cache" not in vols or "/mnt/ddev-global-cache" not in vols: problems.append(f"{path}: ddev-global-cache not mounted at /mnt/ddev-global-cache")
                else:
                    for v in s.get("volumes") or []:
                        if "ddev-global-cache" in flat(v):
                            ro = (isinstance(v, str) and v.endswith(":ro")) or (isinstance(v, dict) and v.get("read_only") is True)
                            if not ro: problems.append(f"{path}: ddev-global-cache mount {v!r} is not read-only")
                gv = (data.get("volumes") or {}).get("ddev-global-cache")
                if not gv or gv.get("external") is not True: problems.append(f"{path}: top-level volumes.ddev-global-cache must be external: true")
            if kind == "engine":
                for k in ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE"):
                    if env.get(k) != "/tmp/meridian-ca-bundle.pem": problems.append(f"{path}: {k} is {env.get(k)!r}")
                if s.get("init") is not True: problems.append(f"{path}: init: true missing")
                if "sleep" not in flat(s.get("command")) and "entrypoint" not in flat(s.get("entrypoint")): problems.append(f"{path}: command should be sleep infinity behind the CA entrypoint")
                if "entrypoint.sh" not in flat(s.get("entrypoint")) + flat(s.get("command")): problems.append(f"{path}: entrypoint.sh not wired")
                if s.get("working_dir") != "/var/www/html/services/engine": problems.append(f"{path}: working_dir {s.get('working_dir')!r}")
            if kind == "next":
                if env.get("VIRTUAL_HOST") != "meridian.ddev.site": problems.append(f"{path}: VIRTUAL_HOST {env.get('VIRTUAL_HOST')!r}")
                if env.get("HTTPS_EXPOSE") != "3001:3000": problems.append(f"{path}: HTTPS_EXPOSE {env.get('HTTPS_EXPOSE')!r}, want 3001:3000")
                if "HTTP_EXPOSE" in env: problems.append(f"{path}: HTTP_EXPOSE present: HTTPS-only exposure is the decision (fallback needs a TA re-check)")
                if env.get("NODE_EXTRA_CA_CERTS") != "/mnt/ddev-global-cache/mkcert/rootCA.pem": problems.append(f"{path}: NODE_EXTRA_CA_CERTS {env.get('NODE_EXTRA_CA_CERTS')!r}")
                if s.get("working_dir") != "/var/www/html/apps/web": problems.append(f"{path}: working_dir {s.get('working_dir')!r}")
                if "start.sh" not in flat(s.get("command")) + flat(s.get("entrypoint")): problems.append(f"{path}: start.sh not wired")
                if env.get("npm_config_cache") != "/tmp/.npm": problems.append(f"{path}: npm_config_cache {env.get('npm_config_cache')!r}")
            else:
                if "HTTPS_EXPOSE" in env or "HTTP_EXPOSE" in env or "VIRTUAL_HOST" in env: problems.append(f"{path}: router variables on a non-web service")
        elif name == "pg":
            if kind != "postgres": continue
            env = kv(s.get("environment"))
            if env.get("POSTGRES_DB") != "meridian": problems.append(f"{path}: POSTGRES_DB {env.get('POSTGRES_DB')!r}")
            if env.get("POSTGRES_USER") != "meridian": problems.append(f"{path}: POSTGRES_USER {env.get('POSTGRES_USER')!r}")
            ia = env.get("POSTGRES_INITDB_ARGS", "")
            if "--encoding=UTF8" not in ia or "--locale=C.UTF-8" not in ia: problems.append(f"{path}: POSTGRES_INITDB_ARGS {ia!r}")
            if "POSTGRES_PASSWORD" in env and "$" not in env["POSTGRES_PASSWORD"]: problems.append(f"{path}: POSTGRES_PASSWORD literal")
            ep = flat(s.get("entrypoint")) + flat(s.get("command"))
            for p in ("MERIDIAN_POSTGRES_PASSWORD", "docker-entrypoint.sh", "exec"):
                if p not in ep: problems.append(f"{path}: entrypoint/command lacks {p} (password must come from MERIDIAN_POSTGRES_PASSWORD)")
            m = [v for v in (s.get("volumes") or []) if "/var/lib/postgresql/data" in flat(v)]
            if not m: problems.append(f"{path}: nothing mounted at /var/lib/postgresql/data")
            else:
                src = m[0].split(":")[0] if isinstance(m[0], str) else m[0].get("source", "")
                if src.startswith(("/", ".", "$")) and "postgres-data" not in src: problems.append(f"{path}: data mount {src!r} is a bind mount, want a named volume")
                tv = data.get("volumes") or {}
                key = [k for k in tv if "postgres-data" in k or "postgres-data" in str((tv[k] or {}).get("name", ""))]
                if not key: problems.append(f"{path}: no top-level volume for postgres data")
                else:
                    lab = kv((tv[key[0]] or {}).get("labels"))
                    for l in ("com.ddev.site-name", "com.ddev.approot"):
                        if l not in lab: problems.append(f"{path}: data volume lacks label {l}")
check(sys.argv[1])
if problems:
    print("\n".join(problems)); sys.exit(1)
PY
cc() { need_file "$CPG" && need_file "$CEN" && need_file "$CWB" || return 1; python3 -I "$WORK/cc.py" "$1"; }
ccone() { python3 -I "$WORK/cc.py" "$1"; }

# =====================================================================================================
if [[ "$MODE" != liveonly && "$MODE" != clone ]]; then

case_start TC-T06-01 "compose files, service names, container names and DDEV labels (AC1, KD-2)"
ckp "the three compose files exist, each defines only its one section 0 service" cc names
ckp "no old placeholder service names in .ddev compose files (files must exist)" bash -c "[[ -s $CPG && -s $CEN && -s $CWB ]] && ! cat $CPG $CEN $CWB 2>/dev/null | grep -qiE 'trading''-agent|trading''_engine|trading''_ingest'"
ckp "no other docker-compose.*.yaml in .ddev (exactly postgres, engine, next)" bash -c \
  "[[ \$(ls .ddev/docker-compose.*.yaml 2>/dev/null | sort | tr '\n' ' ') == '$CPG $CEN $CWB ' ]]"
ckp "each compose file starts with a comment naming T06" bash -c "for f in $CPG $CEN $CWB; do head -5 \$f | grep -q 'T06' || { echo \"\$f: no T06 comment\"; exit 1; }; done"

case_start TC-T06-02 "images pinned by exact tag and digest (AC1, KD-2, KD-4 to KD-6, dependency policy)"
ckp "postgres:16.x, python:3.12.x-slim and node:22.x each pinned name:tag@sha256:<64 hex>; no latest; no build:" cc images
ckp "official Docker Hub images only (no registry host, no third-party namespace)" bash -c \
  "for f in $CPG $CEN $CWB; do grep -E '^\s*image:' \$f | grep -qE 'image:\s*(postgres|python|node):' || { echo \"\$f: image is not an official postgres, python or node image\"; exit 1; }; done"
ckp "CODING_STANDARDS Docker rule no longer says 'where T06 confirms it'" bash -c "[[ -s docs/standards/CODING_STANDARDS.md ]] && ! grep -q 'where T06 confirms it' docs/standards/CODING_STANDARDS.md && ! grep -q 'plus digest where T06 confirms' docs/standards/CODING_STANDARDS.md"

case_start TC-T06-03 "health checks defined on all three services (AC5, KD-4 to KD-6)"
ckp "healthcheck with test, interval, timeout, retries, start_period; per-service content as the plan; engine and web checks do not call Postgres or Drupal" cc health
ckp "no restart policy on any service (a dead container must stay down for the status command)" bash -c "[[ -s $CPG && -s $CEN && -s $CWB ]] && ! grep -hqE '^\s*restart:' $CPG $CEN $CWB"

case_start TC-T06-04 "env_file order, no values in compose, no new project variable (KD-3, C6)"
ckp "env_file is [\${DDEV_APPROOT}/.env.example (required), \${DDEV_APPROOT}/.env (required: false)] on every service" cc envfile
ckp "no secret-like literal, no .env.example placeholder value in any compose file" cc plain
ckp "no .ddev/.env or .ddev/.env.* file (single source: root .env)" bash -c "[[ -z \$(ls -A .ddev/.env .ddev/.env.* 2>/dev/null || true) ]]"
ckp "compose files reference only variable names already in .env.example" bash -c "
  for f in $CPG $CEN $CWB; do [[ -s \$f ]] || { echo \"missing \$f\"; exit 1; }; done
  for v in \$(grep -ohE '\\\$\\\$?\{?MERIDIAN_[A-Z_]+|\\\$\\\$?\{?DRUPAL_[A-Z_]+' $CPG $CEN $CWB | tr -d '\${}' | sort -u); do
    grep -q \"^\$v=\" .env.example || { echo \"\$v not in .env.example\"; exit 1; }; done"

case_start TC-T06-05 "no host ports, no extra router variables, shared service settings (AC2, KD-2, KD-4)"
ckp "no ports:, no restart:, networks (if declared) include default and ddev_default; non-postgres services run as DDEV_UID:DDEV_GID with HOME=/tmp and the repo mounted at /var/www/html" cc plain
ckp "meridian-postgres has no router variables, no expose of 5432 to the host" bash -c "[[ -s $CPG ]] && ! grep -qE 'VIRTUAL_HOST|HTTPS?_EXPOSE|^\s*ports:' $CPG"

case_start TC-T06-06 "router route and CA trust wiring (AC2, AC6a, KD-5, KD-6)"
ckp "web: VIRTUAL_HOST meridian.ddev.site, HTTPS_EXPOSE=3001:3000, no HTTP_EXPOSE, NODE_EXTRA_CA_CERTS, working_dir apps/web, start.sh; engine: SSL_CERT_FILE and REQUESTS_CA_BUNDLE bundle, init true, entrypoint.sh, working_dir services/engine; both: external_links ddev-router:meridian.ddev.site and read-only ddev-global-cache (external)" cc router

case_start TC-T06-07 "meridian-postgres service and data volume (AC4, KD-4)"
ckp "POSTGRES_DB and POSTGRES_USER meridian, UTF8 / C.UTF-8 initdb args, password from MERIDIAN_POSTGRES_PASSWORD via exec docker-entrypoint.sh, health check pg_isready, named data volume at /var/lib/postgresql/data with both DDEV labels" cc pg
ckp "health check retries 12 and pg_isready target 127.0.0.1" cc health
ckp "negative: no literal POSTGRES_PASSWORD value" bash -c "[[ -s $CPG ]] && ! grep -E 'POSTGRES_PASSWORD\s*[:=]\s*[A-Za-z0-9_-]+\s*\$' $CPG"

case_start TC-T06-08 "host commands engine, next, pg, meridian-status: form and annotations (AC3)"
for c in "$CENG" "$CNEXT" "$CPGC" "$CSTAT_CMD"; do
  ckp "$c: exists, executable, bash shebang, set -euo pipefail" bash -c "[[ -x '$c' ]] && head -1 '$c' | grep -qE '^#!/(usr/)?bin/(env )?bash' && grep -q 'set -euo pipefail' '$c'"
  ckp "$c: ## Description, ## Usage, ## Example headers; no ## Flags (arguments pass through unparsed)" bash -c "grep -q '^## Description' '$c' && grep -q '^## Usage' '$c' && grep -q '^## Example' '$c' && ! grep -q '^## Flags' '$c'"
  ckp "$c: handles -h/--help (exit 0) and sends usage errors to stderr with exit 2" bash -c "grep -qE -- '-h|--help' '$c' && grep -qE 'exit 2' '$c' && grep -qE '>&2' '$c'"
  ckp "$c: parses (bash -n)" bash -n "$c"
done
ckp "engine runs in meridian-engine at /var/www/html/services/engine and forwards \"\$@\"" allin "$CENG" 'meridian-engine' '/var/www/html/services/engine' '"\$@"'
ckp "next runs in meridian-web at /var/www/html/apps/web and forwards \"\$@\"" allin "$CNEXT" 'meridian-web' '/var/www/html/apps/web' '"\$@"'
ckp "engine and next do not use eval, sh -c string building or unquoted \$*" bash -c "! grep -nE '\beval\b|\\\$\*' '$CENG' '$CNEXT'"
ckp "pg offers psql, dump and restore; psql as user meridian on database meridian" allin "$CPGC" 'psql' 'dump' 'restore' '-U meridian' '-d meridian'
ckp "meridian-status lists all five services and uses docker inspect" allin "$CSTAT_CMD" "\bweb\b" "\bdb\b" 'meridian-postgres' 'meridian-engine' 'meridian-web' 'docker inspect'
ckp "ddev e2e, status and describe are not overridden (e2e is T27)" bash -c "[[ ! -e $CMDD/e2e && ! -e $CMDD/status && ! -e $CMDD/describe && ! -e .ddev/commands/web/e2e ]]"

case_start TC-T06-09 "pg dump and restore script logic (AC4, KD-8)"
ckp "dump: custom format, --no-owner, --no-acl, default path under db-dumps/ with a UTC timestamp, umask 077, temp file then rename" allin "$CPGC" 'pg_dump' '-Fc' '--no-owner' '--no-acl' 'db-dumps/' 'meridian-postgres-' 'umask 077' '\bmv\b'
ckp "restore requires --yes and explains that it replaces the database" allin "$CPGC" '--yes' 'replace'
ckp "restore validates the archive (pg_restore --list) BEFORE dropdb" bash -c "[[ -s '$CPGC' ]] && l=\$(grep -nE 'pg_restore.*--list|pg_restore -l' '$CPGC' | head -1 | cut -d: -f1) && d=\$(grep -nE 'dropdb' '$CPGC' | head -1 | cut -d: -f1) && [[ -n \$l && -n \$d && \$l -lt \$d ]] || { echo \"list line=\$l dropdb line=\$d: validation must come first\"; exit 1; }"
ckp "restore: dropdb --force --if-exists, createdb -O meridian, pg_restore --exit-on-error --no-owner --no-acl from stdin" allin "$CPGC" 'dropdb.*--force' '--if-exists' 'createdb' '-O meridian' 'pg_restore' '--exit-on-error'
ckp "streams use docker exec -i (no TTY, no ddev exec for binary data)" allin "$CPGC" 'docker exec -i'
ckp "negative: no password on a command line or in the script" allout "$CPGC" 'PGPASSWORD=\S|--password|MERIDIAN_POSTGRES_PASSWORD=\S'

case_start TC-T06-10 "meridian-status logic (AC5, KD-10)"
ckp "prints SERVICE STATE HEALTH, reports missing containers, exits 1 when any is not running+healthy, names the bad services last" allin "$CSTAT_CMD" 'State\.Status' 'State\.Health\.Status' 'missing' 'exit 1' 'running' 'healthy'
ckp "no colour codes unless stdout is a terminal" bash -c "! grep -qE '\\\\033|\\\\e\[' '$CSTAT_CMD' || grep -qE '\[ -t 1 \]|\[\[ -t 1 \]\]' '$CSTAT_CMD'"
ckp "container names: ddev-meridian-web, ddev-meridian-db and ddev-meridian-<service>" allin "$CSTAT_CMD" 'ddev-meridian|ddev-\$\{?[A-Za-z_]+\}?-'

case_start TC-T06-11 "helper scripts and the placeholder server (AC6a, KD-1, KD-5, KD-6)"
ckp "entrypoint.sh, start.sh executable, bash -n clean, set -euo pipefail" bash -c "for f in $EPT $WST; do [[ -x \$f ]] && bash -n \$f && grep -q 'set -euo pipefail' \$f || { echo \"bad \$f\"; exit 1; }; done"
ckp "entrypoint builds /tmp/meridian-ca-bundle.pem from the system bundle and the mkcert root, warns on stderr if the root is absent, then exec \"\$@\"" allin "$EPT" '/etc/ssl/certs/ca-certificates\.crt' '/mnt/ddev-global-cache/mkcert/rootCA\.pem' '/tmp/meridian-ca-bundle\.pem' '>&2' 'exec "\$@"'
ckp "start.sh switches on apps/web/package.json: npm run dev -- --hostname 0.0.0.0 --port 3000, else the placeholder server" allin "$WST" 'apps/web/package\.json' 'exec npm run dev' '--hostname 0\.0\.0\.0' '--port 3000' 'placeholder-server\.mjs'
ckp "placeholder is at most 40 lines, node:http only, no import of a package" bash -c "[[ -s $WPH ]] && [[ \$(wc -l <$WPH) -le 40 ]] && grep -q 'node:http' $WPH && ! grep -E \"^\s*(import|require).*['\\\"][a-z@]\" $WPH | grep -v 'node:' | grep -q ."
ckp "placeholder text is exactly the fixed sentence (names T21), listens on 0.0.0.0:3000, answers 200 text/plain" allin "$WPH" "$PLACEHOLDER" '0\.0\.0\.0' '3000' 'text/plain' '200'
ckp "placeholder serves no data: no fs, no process.env, no fetch" allout "$WPH" 'node:fs|process\.env|fetch\(|readFile'
ckp "no README in .ddev/meridian-engine or .ddev/meridian-web (ignored by .ddev/.gitignore; documented in .ddev/README.md)" bash -c "[[ -z \$(ls .ddev/meridian-engine/README.* .ddev/meridian-web/README.* 2>/dev/null || true) ]]"

case_start TC-T06-12 "scope discipline: runtimes only (KD-1, non-goals)"
cka "no services/engine/pyproject.toml (T13)" bash -c "[[ ! -e services/engine/pyproject.toml ]]"
cka "no apps/web/package.json tracked or present (T21; the start-script switch is tested in a scratch clone only)" bash -c "[[ ! -e apps/web/package.json && -z \$(git ls-files apps/web/package.json) ]]"
cka "no Dockerfile in the repo (T13, T21)" bash -c "[[ -z \$(git ls-files | grep -iE '(^|/)Dockerfile' || true) ]]"
cka "no ddev e2e command (T27)" bash -c "[[ ! -e $CMDD/e2e ]]"
cka ".ddev/config.yaml unchanged since the branch point $BASE" bash -c "git diff --quiet $BASE -- .ddev/config.yaml"
cka "scripts/quality.sh and .ddev/commands/host/quality unchanged (the ddev runner already maps to ddev engine / ddev next)" bash -c "git diff --quiet $BASE -- scripts/quality.sh $CMDD/quality"
ckp "quality.sh maps the ddev runner to ddev engine and ddev next" allin scripts/quality.sh 'ddev engine' 'ddev next'
ckp "no providers/pantheon.yaml (T07) and no ci.yml DDEV job (T08)" bash -c "[[ ! -e .ddev/providers/pantheon.yaml ]] && { [[ ! -e .github/workflows/ci.yml ]] || ! grep -qi ddev .github/workflows/ci.yml; }"

case_start TC-T06-13 "git ignore: dumps and generated files stay out of git (AC4, C6)"
ckp "git check-ignore -v names the root .gitignore for db-dumps/x.dump and any .dump" bash -c "git check-ignore -v db-dumps/meridian-postgres-20260101T000000Z.dump | grep -q '\.gitignore' && git check-ignore -q some/where/x.dump"
ckp "no tracked file matches an ignore rule (.ddev, docs/tests/T06)" bash -c "[[ -z \$(git ls-files -ci --exclude-standard -- .ddev docs/tests/T06) ]]"
ckp "the new .ddev files are NOT ignored (compose, commands, helpers)" bash -c "for f in \$(ls $CPG $CEN $CWB $CENG $CNEXT $CPGC $CSTAT_CMD $EPT $WST $WPH 2>/dev/null); do ! git check-ignore -q \$f || { echo \"ignored: \$f\"; exit 1; }; done; [[ -n \$(ls $CPG 2>/dev/null) ]] || { echo 'no implementation files yet'; exit 1; }"
ckp "no dump file or db-dumps/ content tracked" bash -c "[[ -z \$(git ls-files | grep -E '\.dump\$|^db-dumps/' || true) ]]"
ckp "no .env tracked" bash -c "[[ -z \$(git ls-files | grep -E '(^|/)\.env\$' || true) ]]"

case_start TC-T06-14 "documentation updated (C5, AC3, decision condition 3)"
ckp "runbook documents ddev engine, ddev next, ddev pg psql/dump/restore (--yes), ddev meridian-status" allin "$RB" 'ddev engine' 'ddev next' 'ddev pg psql' 'ddev pg dump' 'ddev pg restore' '--yes' 'ddev meridian-status'
ckp "runbook: port 3001 URL serves a placeholder until T21" allin "$RB" 'https://meridian\.ddev\.site:3001' 'placeholder' 'T21'
ckp "runbook: ddev delete removes Postgres data, run ddev pg dump first; dumps stay out of git and chat" allin "$RB" 'ddev delete' 'ddev pg dump' 'db-dumps|\.dump'
ckp "runbook: password change after first init (ALTER ROLE), mkcert root, port check, .env visible to all containers" allin "$RB" 'ALTER ROLE' 'mkcert' 'ss -ltn|port 3001' '\.env'
ckp "runbook keeps the template headings and the T05 steps" allin "$RB" '^# Runbook' '^## Steps' '^## Verification' '^## Rollback' 'ddev drupal-install'
ckp ".ddev/README.md: three compose files, four commands, e2e is T27 not T06, placeholder until T21, Verified facts (T06) table" allin "$DR" 'docker-compose\.postgres\.yaml' 'docker-compose\.engine\.yaml' 'docker-compose\.next\.yaml' 'ddev engine' 'ddev pg' 'ddev next' 'meridian-status' 'placeholder' 'T21' 'Verified facts'
ckp ".ddev/README.md no longer lists ddev e2e under T06" bash -c "! grep -E 'ddev e2e' $DR | grep -q 'T06'"
ckp "CLAUDE.md Commands table lists ddev engine, ddev next, ddev pg and ddev meridian-status" allin CLAUDE.md 'ddev engine' 'ddev next' 'ddev pg' 'meridian-status'
ckp "root README local stack paragraph mentions the five services or the placeholder" allin README.md 'meridian-postgres|Postgres' 'placeholder|T21'
ckp "services/engine/README.md and apps/web/README.md name the container; apps/web README says 3001 serves a placeholder until T21" bash -c "grep -qi 'meridian-engine' services/engine/README.md && grep -qi 'meridian-web' apps/web/README.md && grep -qiE 'placeholder' apps/web/README.md && grep -q 'T21' apps/web/README.md"
ckp "technical-design D7: T06 result recorded (router, mkcert, NODE_EXTRA_CA_CERTS/SSL_CERT_FILE, 3001); the 'unverified (T06)' sentence is gone" bash -c "f=docs/architecture/technical-design.md; grep -q 'ddev-router' \$f && grep -q 'NODE_EXTRA_CA_CERTS' \$f && grep -q 'meridian.ddev.site:3001' \$f && ! grep -q 'is \*\*unverified\*\* (T06)' \$f"
ckp "technical-design open-items row for DDEV in-container resolution is marked resolved" bash -c "grep 'DDEV in-container resolution' docs/architecture/technical-design.md | grep -qiE 'resolved|closed|done'"
ckp "docs state no overclaim: no doc says the Next.js dev server runs in T06" bash -c "! grep -rniE 'next\.js dev server (runs|is running|answers) (in|on) (the )?(ddev|port 3001)' $RB $DR apps/web/README.md README.md"

case_start TC-T06-15 ".env.example: names and values unchanged, comments only (C6, KD-3, KD-9)"
envpairs() { git show "$1:.env.example" 2>/dev/null | grep -E '^[A-Z_][A-Z0-9_]*=' ; }
env_same() { local a b; a=$(envpairs "$BASE") || true; b=$(grep -E '^[A-Z_][A-Z0-9_]*=' .env.example || true)
  [[ -n "$a" ]] || { echo "cannot read .env.example at $BASE"; return 1; }
  [[ "$a" == "$b" ]] || { echo "variable lines differ from $BASE:"; diff <(echo "$a") <(echo "$b") | head; return 1; }; }
cka ".env.example variable names and values are identical to $BASE (comments may differ)" env_same
ckp ".env.example MERIDIAN_WEB_BASE_URL is still https://meridian.ddev.site:3001 and the Drupal base URLs are https://meridian.ddev.site" allin .env.example '^MERIDIAN_WEB_BASE_URL=https://meridian\.ddev\.site:3001$' '^MERIDIAN_DRUPAL_BASE_URL=https://meridian\.ddev\.site$' '^DRUPAL_BASE_URL=https://meridian\.ddev\.site$'
ckp ".env.example comment no longer says 'host fixed in T06'" bash -c "! grep -q 'host fixed in T06' .env.example"
ckp "no new variable name appears in the compose files, helper scripts or commands (files must exist)" bash -c "
  [[ -s $CPG && -s $CEN && -s $CWB && -s $CPGC && -s $EPT ]] || { echo 'implementation files missing'; exit 1; }
  for v in \$(cat $CPG $CEN $CWB $CENG $CNEXT $CPGC $CSTAT_CMD $EPT $WST 2>/dev/null | grep -ohE '\b(MERIDIAN|DRUPAL)_[A-Z0-9_]+' | sort -u); do grep -q \"^\$v=\" .env.example || { echo \"\$v is not defined in .env.example\"; exit 1; }; done"

case_start TC-T06-16 "no secrets in T06 files (C6)"
SECRE='BEGIN [A-Z ]*PRIVATE KEY|sk-ant-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20}|xox[bp]-[0-9A-Za-z-]{10}'
nosecret() { local f; [[ -n "$(t06_impl_files)" ]] || { echo "no T06 implementation files yet"; return 1; }
  f=$(t06_files)
  ! echo "$f" | xargs -d '\n' grep -IEn "$SECRE" 2>/dev/null || { echo "secret-shaped string found"; return 1; }; }
ckp "no key, token or credential pattern in any T06 file" nosecret
ckp "the mkcert CA key (rootCA-key.pem) is never read or copied by T06 files (files must exist)" bash -c "[[ -s $EPT && -s $CEN ]] && ! cat $EPT $WST $CPG $CEN $CWB $CENG $CNEXT $CPGC $CSTAT_CMD 2>/dev/null | grep -q 'rootCA-key'"
ckp "ddev-global-cache is mounted read-only wherever it appears" bash -c "[[ -s $CEN && -s $CWB ]] && ! grep -h 'ddev-global-cache' $CEN $CWB | grep -E ':/mnt/ddev-global-cache' | grep -vE ':ro|read_only'"
if command -v gitleaks >/dev/null 2>&1; then
  ckp "gitleaks over the working tree" gitleaks detect --no-git --source . --no-banner --redact
else skip "gitleaks not on PATH: the pre-commit hook covers it (TC-T06-19)"; fi

case_start TC-T06-17 "simulation-only denylist over T06 files (FR-11, ADR-0006, CLAUDE.md)"
BR='zerodha|kite ?connect|\bkite\b|kiteconnect|upstox|angel ?(one|broking)|groww|fyers|5paisa|dhanhq|\bdhan\b|alice ?blue|interactive ?brokers|ibkr|alpaca|icici ?direct|smartapi|kite\.trade|place[_ -]?order|order[_ -]?placement'
deny_files() { local f; f=$(t06_impl_files); [[ -n "$f" ]] || { echo "no T06 implementation files to scan yet"; return 1; }
  ! echo "$f" | xargs grep -IinE "$BR" 2>/dev/null || { echo "denylist hit in T06 files"; return 1; }; }
ckp "denylist scan over every T06 implementation file (non-empty set required)" deny_files
deny_docs() { local f; f=$(t06_files | grep -vE '^docs/tests/'); [[ -n "$f" ]] || { echo "no changed docs yet"; return 1; }
  ! echo "$f" | xargs -d '\n' grep -IinE "$BR" 2>/dev/null || { echo "denylist hit in T06 docs"; return 1; }; }
ckp "denylist scan over the files T06 changes outside docs/tests" deny_docs
ckp "images are only postgres, python, node; no broker or trading image or package" bash -c "[[ -s $CPG ]] && ! grep -hiE '^\s*image:' $CPG $CEN $CWB | grep -viE 'image:\s*(postgres|python|node):' "
ckp "no outbound host in T06 helper scripts other than meridian.ddev.site, 127.0.0.1, localhost" bash -c "f=\$(ls $EPT $WST $WPH 2>/dev/null); [[ -n \$f ]] && ! grep -hoE 'https?://[^ \"'\\'')]+' \$f | grep -vE 'meridian\.ddev\.site|127\.0\.0\.1|localhost|0\.0\.0\.0'"

case_start TC-T06-18 "naming (section 0, C-criteria)"
ckp "scripts/check-names.sh passes" scripts/check-names.sh
ckp "service names and container names use the section 0 names (meridian-postgres, meridian-engine, meridian-web)" cc names
ckp "no old placeholder names in T06 files (case-insensitive)" bash -c "f=\$(ls $CPG $CEN $CWB $CENG $CNEXT $CPGC $CSTAT_CMD $EPT $WST $WPH 2>/dev/null); [[ -n \"\$f\" ]] && ! echo \"\$f\" | xargs grep -IinE 'trading''-agent|trading''_engine|trading''_ingest'"

case_start TC-T06-19 "hygiene: shellcheck, yamllint, check-yaml, pre-commit on T06 files, earlier regression sets (C4)"
if command -v shellcheck >/dev/null 2>&1; then
  ckp "shellcheck on the four commands and the two helper scripts" bash -c "shellcheck -s bash $CENG $CNEXT $CPGC $CSTAT_CMD $EPT $WST"
else skip "shellcheck not on PATH: the pre-commit shellcheck hook covers it"; fi
if command -v yamllint >/dev/null 2>&1; then
  ckp "yamllint (.yamllint.yaml) on the three compose files" yamllint -c .yamllint.yaml "$CPG" "$CEN" "$CWB"
else skip "yamllint not on PATH: covered by the pre-commit yamllint hook below"; fi
PC=.tools/pre-commit
if [[ -x "$PC" ]]; then
  pc_files() { { t06_files; } | while IFS= read -r f; do [[ -f "$f" ]] && printf '%s\n' "$f"; done; }
  pc_run() { local f; f=$(pc_files); [[ -n "$f" ]] || { echo "no files"; return 1; }
    echo "$f" | xargs -d '\n' "$PC" run --files; }
  ckp "pre-commit run --files <every T06 file> exits 0 (never --all-files here; T05 TC-T05-24 owns that)" pc_run
else skip ".tools/pre-commit not bootstrapped: run scripts/bootstrap-dev.sh"; fi
ckp "T05 run-checks.sh --regression exits 0 (TC-T05-15 and 23 re-tagged cka by the tester)" bash -c "docs/tests/T05/run-checks.sh --regression >'$WORK/t05.txt' 2>&1 || { grep -E '^\s+FAIL' '$WORK/t05.txt' | head -8; exit 1; }"
ckp "T04a, T03 and T04 regression sets exit 0" bash -c "for t in T04a T03 T04; do docs/tests/\$t/run-checks.sh --regression >'$WORK/r.txt' 2>&1 || { echo \"\$t regression failed\"; grep -E '^\s+FAIL' '$WORK/r.txt' | head -5; exit 1; }; done"

fi   # static

# =====================================================================================================
have_ddev() { command -v ddev >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

declare -A LT=(
  [20]="ddev start: five containers running and healthy (AC1)"
  [21]="ddev stop and start manage the new containers by label (AC1, KD-2)"
  [22]="engine reaches meridian-postgres:5432 (AC2)"
  [23]="engine reaches https://meridian.ddev.site with trusted TLS (AC2)"
  [24]="meridian-web reaches Drupal over trusted HTTPS (AC2)"
  [25]="ddev engine: argument fidelity, cwd, exit status, stdin (AC3)"
  [26]="ddev next: argument fidelity, cwd, exit status (AC3)"
  [27]="ddev pg psql (AC3)"
  [28]="usage and exit codes of the four commands (AC3)"
  [29]="QUALITY_STEPS probe through ddev engine and ddev next (AC3, KD-7)"
  [30]="ddev quality exits 0 with engine and web steps SKIP (C4)"
  [31]="rows survive ddev restart (AC4)"
  [32]="rows survive stop/start and poweroff/start; volume labels (AC4)"
  [33]="dump and restore round trip (AC4)"
  [34]="dump and restore negatives: --yes guard, bad files, open session, explicit path, failed dump (AC4)"
  [35]="meridian-status healthy: exit 0, five running healthy lines (AC5)"
  [36]="stopped meridian-engine is reported: exit 1, named (AC5)"
  [37]="stopped meridian-postgres is reported; no cascade to engine or web health (AC5)"
  [38]="stopped meridian-web is reported (AC5)"
  [39]="unhealthy meridian-engine is reported (AC5)"
  [40]="AC6a: https://meridian.ddev.site:3001/ trusted TLS, 200, placeholder body"
  [41]="AC6a negative: no HTTP 3000 route, no host port for Postgres or meridian-web"
  [43]="git status clean after start, restart and dump (KD-7 invariant)"
)
LIVE_ORDER=(20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 43)

impl_ready() { [[ -f $CPG && -f $CEN && -f $CWB && -f $CENG && -f $CNEXT && -f $CPGC && -f $CSTAT_CMD ]]; }
st() { docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$1" 2>/dev/null || echo "missing -"; }
wait_state() {   # CONTAINER "running healthy" [TIMEOUT s]
  local t=${3:-180} i=0 s=""
  while (( i < t )); do s=$(st "$1"); [[ "$s" == "$2" ]] && return 0; sleep 3; i=$((i+3)); done
  echo "container $1 is '$s', wanted '$2' after ${t}s"; return 1; }
all_five_ok() { local c; for c in "${FIVE[@]}"; do wait_state "$c" "running healthy" "${1:-180}" || return 1; done; }
status_rc() { rcof ddev meridian-status; }
psql_q() { ddev pg psql -At -c "$1" </dev/null; }
seed_sql="drop table if exists t06_t; create table t06_t(id int primary key, v text); insert into t06_t select g, 'row ' || g from generate_series(1,50) g;"
sum_sql="select md5(string_agg(t::text, ',' order by id)) from t06_t t"
cleanup_tables() { ddev pg psql -q -c "drop table if exists t06_t, t06_extra, t06_persist" </dev/null >/dev/null 2>&1 || true; }

chk_engine_pg() {
  rcof ddev engine python3 -c "import socket; socket.create_connection(('meridian-postgres', 5432), 3); print('connected')"
  ckp "engine opens a TCP connection to meridian-postgres:5432" bash -c "[[ \$RC -eq 0 && \"\$OUT\" == *connected* ]]"
  rcof ddev engine python3 -c "import socket; socket.create_connection(('meridian-postgres', 5999), 3)"
  ckp "negative: port 5999 is refused (the check can fail)" bash -c "[[ \$RC -ne 0 ]]"
  rcof ddev engine python3 -c "import socket; socket.create_connection(('meridian-no-such-host', 5432), 3)"
  ckp "negative: an unknown service name does not resolve" bash -c "[[ \$RC -ne 0 ]]"
}
chk_engine_drupal() {
  rcof ddev engine python3 -c "import urllib.request as u; print(u.urlopen('https://meridian.ddev.site/user/login').status)"
  ckp "HTTPS to https://meridian.ddev.site/user/login, verification ON, prints 200 (or 403)" bash -c "[[ \$RC -eq 0 && \"\$OUT\" =~ (^|[[:space:]])(200|403)\$ ]]"
  rcof ddev engine getent hosts meridian.ddev.site
  local addr rip; addr=$(awk '{print $1}' <<<"$OUT" | head -1)
  rip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' ddev-router 2>/dev/null || true)
  ckp "meridian.ddev.site resolves inside meridian-engine to a ddev-router address ($addr in: $rip)" bash -c "[[ -n '$addr' && ' $rip' == *' $addr '* ]]"
  rcof ddev engine bash -c 'printf "%s|%s" "$SSL_CERT_FILE" "$REQUESTS_CA_BUNDLE"'
  ckp "SSL_CERT_FILE and REQUESTS_CA_BUNDLE both point at /tmp/meridian-ca-bundle.pem in an exec session" eq "$OUT" "/tmp/meridian-ca-bundle.pem|/tmp/meridian-ca-bundle.pem" vars
  rcof ddev engine env -u SSL_CERT_FILE -u REQUESTS_CA_BUNDLE python3 -c "import urllib.request as u; print(u.urlopen('https://meridian.ddev.site/user/login').status)"
  ckp "negative: without the CA variables certificate verification FAILS (trust comes from the bundle, verification is not off)" bash -c "[[ \$RC -ne 0 ]] && grep -qiE 'CERTIFICATE_VERIFY_FAILED|certificate verify failed' <<<\"\$OUT\""
  rcof ddev engine bash -c 'grep -c "BEGIN CERTIFICATE" /tmp/meridian-ca-bundle.pem'
  ckp "bundle keeps the system CAs (more than 50 certificates), so public CAs still work" bash -c "[[ \$RC -eq 0 && \${OUT:-0} -gt 50 ]]"
}
chk_web_drupal() {
  rcof ddev next node -e "fetch(process.env.DRUPAL_BASE_URL + '/user/login').then(r => { console.log(r.status); process.exit(r.ok ? 0 : 1) })"
  ckp "meridian-web fetch of \$DRUPAL_BASE_URL/user/login exits 0 and prints 200 (trusted TLS)" bash -c "[[ \$RC -eq 0 && \"\$OUT\" == *200* ]]"
  rcof ddev next env -u NODE_EXTRA_CA_CERTS node -e "fetch(process.env.DRUPAL_BASE_URL + '/user/login').then(r => { console.log(r.status); process.exit(0) }).catch(e => { console.log('ERR', e.cause && e.cause.code); process.exit(1) })"
  ckp "negative: without NODE_EXTRA_CA_CERTS the fetch fails on certificate trust" bash -c "[[ \$RC -ne 0 ]] && grep -qE 'UNABLE_TO_GET_ISSUER_CERT|SELF_SIGNED|CERT_|unable to verify' <<<\"\$OUT\""
}
chk_ac6a() {
  local o
  o=$(curl -sS --max-time 30 -o "$WORK/b.txt" -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/ 2>&1) || true
  ckp "curl (no -k) to https://meridian.ddev.site:3001/ prints '200 0' (got: $o)" eq "$o" "200 0" curl
  ckp "body is the fixed placeholder sentence, which names T21" bash -c "grep -qF '$PLACEHOLDER' '$WORK/b.txt'"
  o=$(curl -sS --max-time 30 -o /dev/null -w '%{http_code} %{content_type}' https://meridian.ddev.site:3001/any/other/path 2>&1) || true
  OUT=$o
  ckp "any path answers 200 text/plain (got: $o)" bash -c "[[ \"\$OUT\" == '200 text/plain'* ]]"
}

live_checks() {
  local id
  if ! have_ddev; then
    for id in "${LIVE_ORDER[@]}"; do case_start "TC-T06-$id" "${LT[$id]} (live)"
      blk "ddev and/or a Docker daemon not available in this environment: owner-run"; done
    return 0
  fi
  if ! impl_ready; then
    for id in "${LIVE_ORDER[@]}"; do case_start "TC-T06-$id" "${LT[$id]} (live)"
      ran=$((ran+1)); bad "implementation missing (compose files and the four commands): nothing to run"; done
    return 0
  fi
  local t0 t1 before after path garbage

  case_start TC-T06-20 "${LT[20]}"
  t0=$(date +%s); rcof ddev start; t1=$(date +%s)
  note "ddev start (warm) took $((t1-t0)) s"
  ckp "ddev start exits 0" eq "$RC" 0 "ddev start rc"
  ckp "all five containers (web, db, meridian-postgres, meridian-engine, meridian-web) are running and healthy" all_five_ok
  status_rc
  ckp "ddev meridian-status exits 0" eq "$RC" 0 "meridian-status rc"
  ckp "the three new containers report a health status (a health check is defined and running)" bash -c "for c in $C_PG $C_EN $C_WB; do s=\$(docker inspect -f '{{.State.Health.Status}}' \$c 2>/dev/null) && [[ \$s == healthy ]] || { echo \"\$c health='\$s'\"; exit 1; }; done"
  ckp "pg_isready answers inside meridian-postgres" bash -c "docker exec $C_PG pg_isready -U meridian -d meridian -h 127.0.0.1"

  case_start TC-T06-21 "${LT[21]}"
  rcof ddev stop
  ckp "ddev stop exits 0" eq "$RC" 0 "stop rc"
  ckp "no container with label com.ddev.site-name=meridian is still running" bash -c "[[ -z \$(docker ps -q --filter label=com.ddev.site-name=meridian) ]]"
  ckp "the three new containers are not running" bash -c "for c in $C_PG $C_EN $C_WB; do [[ \$(docker inspect -f '{{.State.Status}}' \$c 2>/dev/null || echo gone) != running ]] || { echo \"\$c still running\"; exit 1; }; done"
  t0=$(date +%s); rcof ddev start; t1=$(date +%s); note "ddev start after stop took $((t1-t0)) s"
  ckp "ddev start exits 0 and all five are healthy again" bash -c "[[ \$RC -eq 0 ]]"
  ckp "all five healthy after start" all_five_ok

  case_start TC-T06-22 "${LT[22]}"
  chk_engine_pg
  rcof ddev engine getent hosts meridian-postgres
  ckp "meridian-postgres resolves inside meridian-engine" bash -c "[[ \$RC -eq 0 && -n \"\$OUT\" ]]"

  case_start TC-T06-23 "${LT[23]}"
  chk_engine_drupal

  case_start TC-T06-24 "${LT[24]}"
  chk_web_drupal

  case_start TC-T06-25 "${LT[25]}"
  rcof ddev engine bash -c 'printf "<%s>\n" "$@"' _ 'a b' '' 'c"d'
  ckp "quoting: 'a b', empty and c\"d arrive as three exact arguments" eq "$OUT" $'<a b>\n<>\n<c"d>' args
  rcof ddev engine bash -c 'printf "%s" "$1"' _ '$HOME `id` * ; echo x'
  ckp "shell metacharacters arrive literally (no host or container re-expansion)" eq "$OUT" '$HOME `id` * ; echo x' meta
  rcof ddev engine pwd
  ckp "ddev engine pwd prints /var/www/html/services/engine" eq "$OUT" /var/www/html/services/engine cwd
  rcof ddev engine python3 --version
  ckp "ddev engine python3 --version reaches the container (flags pass through) and is Python 3.12.x" bash -c "[[ \$RC -eq 0 && \"\$OUT\" == 'Python 3.12.'* ]]"
  rcof ddev engine bash -c 'exit 7'
  ckp "the container exit status propagates (7)" eq "$RC" 7 rc
  OUT=$(echo hello | ddev engine cat 2>&1) || true
  ckp "stdin is forwarded (echo hello | ddev engine cat)" eq "$OUT" hello stdin
  rcof ddev engine id -u
  ckp "runs as the host user, not root" bash -c "[[ \"\$OUT\" == '$(id -u)' ]]"
  ckp "a file written through ddev engine is owned by the host user" bash -c "ddev engine touch /var/www/html/.t06-own </dev/null && [[ \$(stat -c %u .t06-own) == \$(id -u) ]]; rc=\$?; rm -f .t06-own; exit \$rc"

  case_start TC-T06-26 "${LT[26]}"
  rcof ddev next bash -c 'printf "<%s>\n" "$@"' _ 'a b' '' 'c"d'
  ckp "quoting: 'a b', empty and c\"d arrive as three exact arguments" eq "$OUT" $'<a b>\n<>\n<c"d>' args
  rcof ddev next pwd
  ckp "ddev next pwd prints /var/www/html/apps/web" eq "$OUT" /var/www/html/apps/web cwd
  rcof ddev next node --version
  ckp "ddev next node --version is v22.x" bash -c "[[ \$RC -eq 0 && \"\$OUT\" == v22.* ]]"
  rcof ddev next bash -c 'exit 5'
  ckp "the container exit status propagates (5)" eq "$RC" 5 rc
  rcof ddev next id -u
  ckp "runs as the host user, not root" bash -c "[[ \"\$OUT\" == '$(id -u)' ]]"

  case_start TC-T06-27 "${LT[27]}"
  rcof ddev pg psql -c 'select 1'
  ckp "ddev pg psql -c 'select 1' exits 0" eq "$RC" 0 rc
  rcof ddev pg psql -At -c 'select current_user || chr(124) || current_database()'
  ckp "connects as user meridian on database meridian" eq "$OUT" 'meridian|meridian' who
  rcof ddev pg psql -At -c "select 'a b'"
  ckp "quoted SQL with a space passes through unchanged" eq "$OUT" 'a b' quoting
  rcof ddev pg psql -At -c 'show server_version'
  ckp "server major version is 16" bash -c "[[ \"\$OUT\" == 16.* ]]"
  rcof ddev pg psql -At -c 'show server_encoding'
  ckp "database encoding is UTF8" eq "$OUT" UTF8 encoding
  rcof ddev pg psql -c 'select * from t06_no_such_table'
  ckp "negative: a failing statement gives a non-zero exit" bash -c "[[ \$RC -ne 0 ]]"

  case_start TC-T06-28 "${LT[28]}"
  local c
  for c in engine next pg meridian-status; do
    rcof ddev "$c" --help
    ckp "ddev $c --help exits 0 and prints Usage" bash -c "[[ \$RC -eq 0 ]] && grep -qi usage <<<\"\$OUT\""
  done
  for c in engine next pg; do
    OUT=$(ddev "$c" 2>"$WORK/err.txt" >"$WORK/out.txt" </dev/null; echo $?) || true
    ckp "ddev $c with no argument exits 2 with usage on stderr and nothing on stdout" bash -c "[[ \"\$OUT\" == 2 && -s '$WORK/err.txt' && ! -s '$WORK/out.txt' ]] && grep -qi usage '$WORK/err.txt'"
  done
  rcof ddev pg bogus
  ckp "negative: ddev pg bogus exits 2" eq "$RC" 2 rc
  rcof ddev pg restore
  ckp "negative: ddev pg restore with no file exits 2" eq "$RC" 2 rc
  rcof ddev meridian-status --bogus
  ckp "negative: ddev meridian-status --bogus exits 2" eq "$RC" 2 rc
  ckp "ddev engine python3 --help is passed to python (T06 usage only for a bare --help)" bash -c "ddev engine python3 --help </dev/null 2>&1 | grep -q 'usage: python'"

  case_start TC-T06-29 "${LT[29]}"
  local ecmd ncmd
  ecmd=$(printf 'ddev engine bash -c %q' "test -f ../../scripts/coverage_gate.py && python3 --version")
  ncmd=$(printf 'ddev next bash -c %q' "test -f ../../scripts/coverage_gate.py && node --version")
  printf 'probe-engine\t-\t%s\nprobe-next\t-\t%s\nprobe-fail\t-\t%s\n' "$ecmd" "$ncmd" \
    "$(printf 'ddev engine bash -c %q' 'exit 3')" >"$WORK/steps.tsv"
  QUALITY_RUNNER=ddev QUALITY_STEPS="$WORK/steps.tsv" scripts/quality.sh >"$WORK/q29.txt" 2>&1 </dev/null && RC=0 || RC=$?
  show_out "$(cat "$WORK/q29.txt")"
  ckp "PASS probe-engine (the %q-quoted command reaches meridian-engine in services/engine; ../../scripts/coverage_gate.py resolves)" bash -c "grep -qE '^PASS +probe-engine' '$WORK/q29.txt'"
  ckp "PASS probe-next (same for meridian-web in apps/web)" bash -c "grep -qE '^PASS +probe-next' '$WORK/q29.txt'"
  ckp "negative: FAIL probe-fail (a failing command inside the container is a FAIL, exit status propagates)" bash -c "grep -qE '^FAIL +probe-fail' '$WORK/q29.txt' && [[ \$RC -ne 0 ]]"

  case_start TC-T06-30 "${LT[30]}"
  rcof ddev quality
  printf '%s\n' "$OUT" >"$WORK/q30.txt"
  ckp "ddev quality exits 0 (rc=$RC)" eq "$RC" 0 rc
  ckp "SKIP component-engine (no services/engine/pyproject.toml)" bash -c "grep -E '^\s*SKIP\s+component-engine' '$WORK/q30.txt' | grep -q pyproject"
  ckp "SKIP component-web (no apps/web/package.json)" bash -c "grep -E '^\s*SKIP\s+component-web' '$WORK/q30.txt' | grep -q package.json"
  ckp "PASS component-drupal still passes; no FAIL line" bash -c "grep -qE '^\s*PASS\s+component-drupal\b' '$WORK/q30.txt' && ! grep -qE '^\s*FAIL' '$WORK/q30.txt'"

  case_start TC-T06-31 "${LT[31]}"
  ddev pg psql -q -c "drop table if exists t06_persist; create table t06_persist(id int primary key, v text); insert into t06_persist select g, 'p' || g from generate_series(1,25) g" </dev/null >/dev/null 2>&1 || true
  before=$(psql_q "select md5(string_agg(t::text, ',' order by id)) from t06_persist t" 2>&1 || true)
  ckp "seed present before restart (25 rows, checksum $before)" bash -c "[[ \$(ddev pg psql -At -c 'select count(*) from t06_persist' </dev/null) == 25 ]]"
  rcof ddev restart
  ckp "ddev restart exits 0" eq "$RC" 0 rc
  ckp "all five healthy after restart" all_five_ok
  after=$(psql_q "select md5(string_agg(t::text, ',' order by id)) from t06_persist t" 2>&1 || true)
  ckp "rows and checksum identical after ddev restart" eq "$after" "$before" checksum
  status_rc
  ckp "meridian-status exits 0 after restart" eq "$RC" 0 rc

  case_start TC-T06-32 "${LT[32]}"
  rcof ddev stop; rcof ddev start
  after=$(psql_q "select md5(string_agg(t::text, ',' order by id)) from t06_persist t" 2>&1 || true)
  ckp "checksum identical after ddev stop + ddev start" eq "$after" "$before" checksum
  rcof ddev poweroff; rcof ddev start
  ckp "ddev start after poweroff exits 0" eq "$RC" 0 rc
  ckp "all five healthy after poweroff + start" all_five_ok
  after=$(psql_q "select md5(string_agg(t::text, ',' order by id)) from t06_persist t" 2>&1 || true)
  ckp "checksum identical after ddev poweroff + ddev start" eq "$after" "$before" checksum
  rcof docker volume inspect meridian-postgres-data --format '{{json .Labels}}'
  ckp "docker volume meridian-postgres-data exists and carries com.ddev.site-name and com.ddev.approot" bash -c "[[ \$RC -eq 0 ]] && grep -q 'com.ddev.site-name' <<<\"\$OUT\" && grep -q 'com.ddev.approot' <<<\"\$OUT\""
  ckp "label com.ddev.site-name is meridian" has "$OUT" '"com.ddev.site-name":"meridian"'

  case_start TC-T06-33 "${LT[33]}"
  ddev pg psql -q -c "$seed_sql" </dev/null >/dev/null 2>&1 || true
  before=$(psql_q "$sum_sql" 2>&1 || true)
  rcof ddev pg dump
  ckp "ddev pg dump exits 0" eq "$RC" 0 rc
  path=$(grep -oE '[^ ]*meridian-postgres-[0-9]{8}T[0-9]{6}Z\.dump' <<<"$OUT" | head -1 || true)
  note "dump path: ${path:-none}  (output: ${OUT:0:200})"
  [[ -n "$path" && "$path" != /* ]] && path="$ROOT/$path"
  ckp "a dump file named db-dumps/meridian-postgres-<UTC>.dump exists and is non-empty" bash -c "[[ -n '$path' && -s '$path' && '$path' == */db-dumps/* ]]"
  ckp "the dump is a pg_dump custom archive (magic PGDMP)" bash -c "[[ \$(head -c 5 '$path') == PGDMP ]]"
  ckp "file mode is not group or world readable (umask 077)" bash -c "[[ \$(stat -c %a '$path') =~ ^[0-7]00\$ ]]"
  ckp "git check-ignore -v names the root .gitignore for the dump" bash -c "git check-ignore -v '$path' | grep -q '\.gitignore'"
  ckp "git status --porcelain is empty after the dump" bash -c "[[ -z \$(git status --porcelain) ]]"
  ddev pg psql -q -c "drop table t06_t; create table t06_extra(id int); insert into t06_extra values (1)" </dev/null >/dev/null 2>&1 || true
  ckp "data was changed on purpose (t06_t gone, t06_extra present)" bash -c "[[ \$(ddev pg psql -At -c \"select to_regclass('public.t06_t') is null and to_regclass('public.t06_extra') is not null\" </dev/null) == t ]]"
  rcof ddev pg restore "$path" --yes
  ckp "ddev pg restore <file> --yes exits 0" eq "$RC" 0 rc
  ckp "restore prints a table count" has "$OUT" '[0-9]+'
  after=$(psql_q "$sum_sql" 2>&1 || true)
  ckp "checksum after restore equals the checksum before the dump ($before)" eq "$after" "$before" checksum
  ckp "the extra table created after the dump is gone" bash -c "[[ \$(ddev pg psql -At -c \"select to_regclass('public.t06_extra') is null\" </dev/null) == t ]]"
  ckp "ownership: the restored table belongs to meridian (--no-owner)" bash -c "[[ \$(ddev pg psql -At -c \"select tableowner from pg_tables where tablename='t06_t'\" </dev/null) == meridian ]]"
  ckp "all five still healthy after the restore" all_five_ok
  DUMP_KEEP=$path

  case_start TC-T06-34 "${LT[34]}"
  before=$(psql_q "$sum_sql" 2>&1 || true)
  rcof ddev pg restore "$DUMP_KEEP"
  ckp "no --yes: exit 2" eq "$RC" 2 rc
  ckp "no --yes: message says the database would be replaced" has "$OUT" '(?i)replace|--yes'
  ckp "no --yes: data unchanged" eq "$(psql_q "$sum_sql" 2>&1 || true)" "$before" checksum
  garbage="$WORK/garbage.dump"; printf 'this is not a pg_dump archive\n' >"$garbage"
  rcof ddev pg restore "$garbage" --yes
  ckp "garbage file: exit 1" eq "$RC" 1 rc
  ckp "garbage file: data unchanged (validation happens before dropdb)" eq "$(psql_q "$sum_sql" 2>&1 || true)" "$before" checksum
  head -c 64 "$DUMP_KEEP" >"$WORK/trunc.dump"
  rcof ddev pg restore "$WORK/trunc.dump" --yes
  ckp "truncated archive (64 bytes): non-zero exit" bash -c "[[ \$RC -ne 0 ]]"
  ckp "truncated archive: data unchanged" eq "$(psql_q "$sum_sql" 2>&1 || true)" "$before" checksum
  rcof ddev pg restore "$WORK/does-not-exist.dump" --yes
  ckp "missing file: exit 1" eq "$RC" 1 rc
  ckp "missing file: data unchanged" eq "$(psql_q "$sum_sql" 2>&1 || true)" "$before" checksum
  : >"$WORK/empty.dump"
  rcof ddev pg restore "$WORK/empty.dump" --yes
  ckp "empty file: exit 1 and data unchanged" bash -c "[[ \$RC -eq 1 ]] && [[ \$(ddev pg psql -At -c \"$sum_sql\" </dev/null) == '$before' ]]"
  # open session: pg_sleep holds a connection while restore runs with --force
  ( ddev pg psql -q -c 'select pg_sleep(90)' </dev/null >/dev/null 2>&1 || true ) &
  local bgpid=$!; sleep 4
  ckp "a client session is open on the meridian database" bash -c "[[ \$(docker exec $C_PG psql -U meridian -d postgres -At -c \"select count(*) from pg_stat_activity where datname='meridian' and query like '%pg_sleep%'\") -ge 1 ]]"
  rcof ddev pg restore "$DUMP_KEEP" --yes
  ckp "restore with an open session succeeds (dropdb --force)" eq "$RC" 0 rc
  kill "$bgpid" 2>/dev/null || true; wait "$bgpid" 2>/dev/null || true
  ckp "checksum correct after the forced restore" eq "$(psql_q "$sum_sql" 2>&1 || true)" "$before" checksum
  rcof ddev pg dump "$WORK/explicit.dump"
  ckp "dump to an explicit FILE exits 0, file is a PGDMP archive" bash -c "[[ \$RC -eq 0 && -s '$WORK/explicit.dump' && \$(head -c 5 '$WORK/explicit.dump') == PGDMP ]]"
  ckp "the explicit file restores (round trip from a non-default path)" bash -c "ddev pg restore '$WORK/explicit.dump' --yes </dev/null >/dev/null 2>&1 && [[ \$(ddev pg psql -At -c \"$sum_sql\" </dev/null) == '$before' ]]"
  rcof ddev pg dump /proc/t06-no-such-dir/x.dump
  ckp "failed dump (unwritable target): non-zero exit and no partial file" bash -c "[[ \$RC -ne 0 && ! -e /proc/t06-no-such-dir/x.dump ]]"
  ckp "no stray temporary dump files left in db-dumps/ (*.tmp, *.partial, dot-files)" bash -c "[[ -z \$(ls -A db-dumps 2>/dev/null | grep -vE '^meridian-postgres-[0-9]{8}T[0-9]{6}Z\.dump\$' || true) ]]"
  rm -f "$DUMP_KEEP"
  cleanup_tables

  case_start TC-T06-35 "${LT[35]}"
  all_five_ok >/dev/null 2>&1 || true
  rcof ddev meridian-status
  printf '%s\n' "$OUT" >"$WORK/s35.txt"; show_out "$OUT"
  ckp "exit 0" eq "$RC" 0 rc
  ckp "five service lines, each 'running healthy'" bash -c "[[ \$(grep -cE '^(web|db|meridian-postgres|meridian-engine|meridian-web) +running +healthy' '$WORK/s35.txt') -eq 5 ]]"
  ckp "no colour escape codes in piped output" bash -c "! grep -q \$'\\033' '$WORK/s35.txt'"
  ckp "ddev describe is informational only; it runs (output kept in evidence)" bash -c "ddev describe </dev/null 2>&1 | head -30"

  local svc cn
  for id in 36 37 38; do
    case "$id" in 36) svc=meridian-engine; cn=$C_EN ;; 37) svc=meridian-postgres; cn=$C_PG ;; 38) svc=meridian-web; cn=$C_WB ;; esac
    case_start "TC-T06-$id" "${LT[$id]}"
    docker stop "$cn" >/dev/null 2>&1 || true
    rcof ddev meridian-status
    show_out "$OUT"
    ckp "docker stop $cn: ddev meridian-status exits 1" eq "$RC" 1 rc
    ckp "the $svc line shows exited (and not running)" bash -c "grep -E '^$svc +' <<<\"\$OUT\" | grep -q exited"
    ckp "the last line names $svc" bash -c "tail -1 <<<\"\$OUT\" | grep -q '$svc'"
    ckp "the other services are not named as bad on the last line" bash -c "l=\$(tail -1 <<<\"\$OUT\"); for o in meridian-postgres meridian-engine meridian-web; do [[ \$o == $svc ]] && continue; ! grep -q \"\$o\" <<<\"\$l\" || { echo \"\$o named\"; exit 1; }; done"
    if [[ "$id" == 37 ]]; then
      ckp "no cascade: meridian-engine and meridian-web stay running healthy while Postgres is down" bash -c "[[ \$(docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' $C_EN) == 'running healthy' && \$(docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' $C_WB) == 'running healthy' ]]"
    fi
    note "ddev describe (information only):"; show_out "$(ddev describe </dev/null 2>&1 | head -25 || true)"
    rcof ddev start
    ckp "ddev start brings $svc back" bash -c "[[ \$RC -eq 0 ]]"
    ckp "all five healthy again" all_five_ok
    status_rc
    ckp "meridian-status exits 0 again" eq "$RC" 0 rc
  done

  case_start TC-T06-39 "${LT[39]}"
  docker exec "$C_EN" rm -f /tmp/meridian-ca-bundle.pem >/dev/null 2>&1 || true
  local k=0 s=""
  while (( k < 90 )); do s=$(st "$C_EN"); [[ "$s" == "running unhealthy" ]] && break; sleep 3; k=$((k+3)); done
  note "engine state after ${k}s: $s"
  ckp "the engine health check turns unhealthy within the retry window (3 x 10 s)" eq "$s" "running unhealthy" state
  rcof ddev meridian-status
  show_out "$OUT"
  ckp "meridian-status exits 1" eq "$RC" 1 rc
  ckp "the meridian-engine line shows unhealthy" bash -c "grep -E '^meridian-engine +' <<<\"\$OUT\" | grep -q unhealthy"
  ckp "the last line names meridian-engine" bash -c "tail -1 <<<\"\$OUT\" | grep -q meridian-engine"
  docker restart "$C_EN" >/dev/null 2>&1 || true
  ckp "restarting the container regenerates the bundle and it is healthy again" wait_state "$C_EN" "running healthy" 120

  case_start TC-T06-40 "${LT[40]}"
  chk_ac6a
  ckp "meridian-status shows meridian-web running healthy" bash -c "[[ \$(docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' $C_WB) == 'running healthy' ]]"
  ckp "router sends port 3001 to meridian-web (VIRTUAL_HOST / HTTPS_EXPOSE visible in the container environment)" bash -c "docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' $C_WB | grep -qx 'HTTPS_EXPOSE=3001:3000'"

  case_start TC-T06-41 "${LT[41]}"
  o=$(curl -sS --max-time 10 -o "$WORK/h.txt" -w '%{http_code}' http://meridian.ddev.site:3000/ 2>&1) || true
  ckp "http://meridian.ddev.site:3000/ does not reach the placeholder through the router (got: ${o:0:60})" bash -c "! grep -qF '$PLACEHOLDER' '$WORK/h.txt' 2>/dev/null"
  ckp "meridian-postgres publishes no host port (docker port is empty)" bash -c "[[ -z \$(docker port $C_PG) ]]"
  ckp "meridian-engine and meridian-web publish no host port" bash -c "[[ -z \$(docker port $C_EN) && -z \$(docker port $C_WB) ]]"
  ckp "the router does not bind host port 3000 or 5432 for this project" bash -c "! docker port ddev-router 2>/dev/null | grep -E '^(3000|5432)/'"
  ckp "the router binds 3001 on 127.0.0.1 only" bash -c "docker port ddev-router 2>/dev/null | grep -E '^3001/tcp' | grep -q '127.0.0.1'"

  case_start TC-T06-43 "${LT[43]}"
  ckp "git status --porcelain is empty for the whole repository" bash -c "o=\$(git status --porcelain); echo \"\$o\"; [[ -z \"\$o\" ]]"
  ckp "no tracked file changed by DDEV (git diff --quiet)" git diff --quiet
  ckp "git status --ignored .ddev shows no unexpected generated path (review in the report)" bash -c "git status --ignored --porcelain .ddev | head -20"
}

# =====================================================================================================
clean_clone() {
  local id
  case_start TC-T06-44 "clean clone, no .env: ddev start and five healthy services (C7, AC1)"
  if [[ "${T06_CONFIRM:-0}" != 1 ]]; then
    blk "destructive to the local DDEV registration (ddev stop --unlist meridian); re-run with T06_CONFIRM=1"
    case_start TC-T06-45 "clean clone: AC2 and AC6a checks"; blk "needs TC-T06-44 (T06_CONFIRM=1)"
    case_start TC-T06-46 "clean clone: start-script switch with a temporary package.json"; blk "needs TC-T06-44 (T06_CONFIRM=1)"
    case_start TC-T06-47 "clean clone: ddev delete and the Postgres volume"; blk "needs TC-T06-44 (T06_CONFIRM=1)"
    return 0
  fi
  if ! have_ddev; then
    blk "ddev and/or Docker not available: owner-run"
    for id in 45 46 47; do case_start "TC-T06-$id" "clean-clone case"; blk "needs DDEV"; done
    return 0
  fi
  local scratch br t0 t1 out rc
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/t06clone.XXXXXX"); br=$(git rev-parse --abbrev-ref HEAD)
  ddev stop --unlist meridian >/dev/null 2>&1 || true
  ddev delete -Oy meridian >/dev/null 2>&1 || true
  docker volume rm meridian-postgres-data >/dev/null 2>&1 || true
  if ! git clone -q --branch "$br" "file://$ROOT" "$scratch/meridian" 2>&1; then
    bad "git clone of $br failed"; return 0; fi
  ran=$((ran+1))
  if [[ -n "$(git status --porcelain -- .ddev docs/runbooks scripts CLAUDE.md README.md services apps)" ]]; then
    bad "source tree has uncommitted changes in T06 paths: the clone does not contain them"; ran=$((ran+1)); fi
  cd "$scratch/meridian"
  ckp "the clone has no .env (clean machine)" bash -c "[[ ! -e .env ]]"
  t0=$(date +%s); out=$(ddev start 2>&1) && rc=0 || rc=$?; t1=$(date +%s)
  note "ddev start (cold, first pull included) took $((t1-t0)) s (NFR-17 data point, budget 30 min)"
  ran=$((ran+1))
  if [[ $rc -eq 0 ]]; then pass "ddev start exit 0 with no .env and no manual step"; else bad "ddev start exit $rc"; show_out "$(tail -15 <<<"$out")"; fi
  ckp "all five containers running and healthy" all_five_ok 240
  rcof ddev meridian-status
  ckp "ddev meridian-status exits 0 in the clean clone" eq "$RC" 0 rc
  ckp "git status --porcelain empty after ddev start" bash -c "o=\$(git status --porcelain); echo \"\$o\"; [[ -z \"\$o\" ]]"
  ckp "Postgres initialised from the .env.example placeholder password (login through the socket works)" bash -c "ddev pg psql -At -c 'select 1' </dev/null | grep -qx 1"

  case_start TC-T06-45 "clean clone: AC2 checks and AC6a with no .env"
  chk_engine_pg
  chk_engine_drupal
  chk_web_drupal
  chk_ac6a

  case_start TC-T06-46 "clean clone: start-script switch with a temporary apps/web/package.json (decision condition 2)"
  ckp "precondition: no apps/web/package.json in the clone, placeholder is served" bash -c "[[ ! -e apps/web/package.json ]] && curl -sS --max-time 30 https://meridian.ddev.site:3001/ | grep -qF '$PLACEHOLDER'"
  cat >apps/web/t06-probe.js <<'JS'
const http = require("node:http");
const a = process.argv;
const arg = (n, d) => (a.includes(n) ? a[a.indexOf(n) + 1] : d);
const port = Number(arg("--port", "0")), host = arg("--hostname", "");
http.createServer((q, r) => { r.writeHead(200, { "content-type": "text/plain" }); r.end(`T06-SWITCH-PROBE port=${port} host=${host}\n`); }).listen(port, host);
JS
  printf '{\n  "name": "t06-switch-probe",\n  "private": true,\n  "scripts": { "dev": "node t06-probe.js" }\n}\n' >apps/web/package.json
  docker restart "$C_WB" >/dev/null 2>&1 || true
  ckp "meridian-web is running healthy again with the probe dev server (health: status below 500)" wait_state "$C_WB" "running healthy" 180
  local o
  o=$(curl -sS --max-time 30 -o "$WORK/sw.txt" -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/ 2>&1) || true
  ckp "curl (no -k) returns '200 0' (got: $o)" eq "$o" "200 0" curl
  ckp "body is the probe server's body, with the --port and --hostname arguments start.sh passed (port=3000 host=0.0.0.0)" bash -c "grep -qF 'T06-SWITCH-PROBE port=3000 host=0.0.0.0' '$WORK/sw.txt'"
  ckp "negative: the body is NOT the placeholder sentence" bash -c "! grep -qF '$PLACEHOLDER' '$WORK/sw.txt'"
  rm -f apps/web/package.json apps/web/t06-probe.js
  docker restart "$C_WB" >/dev/null 2>&1 || true
  ckp "after removing package.json and restarting, meridian-web is healthy again" wait_state "$C_WB" "running healthy" 180
  o=$(curl -sS --max-time 30 -o "$WORK/sw2.txt" -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/ 2>&1) || true
  OUT=$o
  ckp "the placeholder is served again (switch works in both directions; got: $o)" bash -c "[[ \"\$OUT\" == '200 0' ]] && grep -qF '$PLACEHOLDER' '$WORK/sw2.txt'"
  ckp "the scratch clone has no package.json left, git status is empty" bash -c "[[ ! -e apps/web/package.json && -z \$(git status --porcelain) ]]"

  case_start TC-T06-47 "clean clone: ddev delete and the Postgres volume (plan KD-4, record the behaviour)"
  ckp "runbook (in the clone) tells the reader to run ddev pg dump before ddev delete" allin docs/runbooks/local-setup.md 'ddev delete' 'ddev pg dump'
  ddev delete -Oy meridian >/dev/null 2>&1 || true
  if docker volume inspect meridian-postgres-data >/dev/null 2>&1; then
    note "RECORDED: meridian-postgres-data still exists after ddev delete -Oy"
    ckp "the runbook must then say that ddev delete keeps the Postgres volume" allin docs/runbooks/local-setup.md 'delete.*(keep|survive|remain|persist)|(keep|survive|remain|persist).*delete'
    docker volume rm meridian-postgres-data >/dev/null 2>&1 || true
  else
    note "RECORDED: meridian-postgres-data was removed by ddev delete -Oy"
    ckp "the runbook says that ddev delete removes the Postgres data (as the plan assumes)" allin docs/runbooks/local-setup.md 'delete.*(remov|drop|destroy|lose|loss)|(remov|drop|destroy|lose|loss).*delete'
  fi
  ckp "no container of the deleted project remains" bash -c "[[ -z \$(docker ps -aq --filter label=com.ddev.site-name=meridian) ]]"
  cd "$ROOT"; rm -rf "$scratch"
  ddev start >/dev/null 2>&1 || emit "  NOTE: could not restart the original working project; run 'ddev start' in $ROOT"
}

case "$MODE" in
  live|liveonly) live_checks ;;
  clone) clean_clone ;;
esac

# =====================================================================================================
if [[ "$MODE" != reg ]]; then
case_start TC-T06-42 "AC6b: the Next.js dev server answers on https://meridian.ddev.site:3001 (deferred to T21)"
blk "Blocked (accepted, re-run in T21): no apps/web/package.json exists until T21, so only the placeholder can be tested (AC6a, TC-T06-40). The owner must accept this deferral in writing at T06 close; an agent message is not acceptance."
note "Procedure for T21 (run unchanged against npm run dev; cite this ID):"
note "  1. ddev next npm ci ; ddev restart ; wait until ddev meridian-status shows meridian-web running healthy (first compile can exceed 120 s: if not, T21 adjusts start_period)"
note "  2. curl -sS -o body.txt -w '%{http_code} %{ssl_verify_result}' https://meridian.ddev.site:3001/   (no -k)"
note "     expect a status below 500 (200, or the 307 redirect from the T21 middleware) and ssl_verify_result 0"
note "  3. the response comes from the Next.js dev server: a known page body or the middleware redirect; body does NOT contain '$PLACEHOLDER'"
note "  4. ddev meridian-status exits 0 and shows meridian-web running healthy"
note "  5. store evidence under docs/tests/T21/evidence/; T21 back-annotates docs/tests/T06/test-report.md (dated addendum)"
case_start TC-T06-48 "AC6a owner-run: https://meridian.ddev.site:3001 opens in the Windows browser without a certificate warning"
blk "owner-run: after ddev start, open https://meridian.ddev.site:3001 in the Windows browser (same mkcert prerequisite as TC-T05-40); expect the placeholder sentence naming T21, no warning; record a screenshot or note"
case_start TC-T06-49 "C7 owner-run: the runbook followed verbatim on a clean machine or container"
blk "owner-run (or tester with a fresh container): follow docs/runbooks/local-setup.md word for word through ddev meridian-status exit 0 and the dump and restore steps; record each command, output and the total time; not automatable"
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
