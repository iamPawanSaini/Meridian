#!/usr/bin/env python3
"""DEF-002 retest model. Models the FIXED documented constraints (data-model.md runs, Revision 3) in sqlite:
  uq_runs_date_attempt: UNIQUE (trade_date, attempt) WHERE attempt > 0
  uq_runs_one_running : UNIQUE (status) WHERE status = 'running'
  ck_runs_attempt     : attempt = 0 exactly when command in (publish, replay)
sqlite is used only to enforce the same partial unique indexes and check that Postgres will."""
import sqlite3, sys
c = sqlite3.connect(":memory:")
c.execute("""create table runs(run_id text primary key, trade_date text not null, attempt int not null,
 command text not null, status text not null,
 constraint ck_runs_attempt check ((attempt = 0) = (command in ('publish', 'replay'))))""")
c.execute("create unique index uq_runs_date_attempt on runs(trade_date, attempt) where attempt > 0")
c.execute("create unique index uq_runs_one_running on runs(status) where status = 'running'")
fails = 0
def t(name, args, should_ok):
    global fails
    try:
        c.execute("insert into runs values(?,?,?,?,?)", args); ok = True; why = ""
    except sqlite3.IntegrityError as e:
        ok = False; why = str(e)
    good = ok == should_ok
    fails += (not good)
    print(("PASS " if good else "FAIL ") + name + " -> " + ("inserted" if ok else "rejected: " + why))
d = "2026-11-02"
t("first publish, attempt 0", ("p1", d, 0, "publish", "success"), True)
t("second publish, same date, attempt 0 (the DEF-002 case)", ("p2", d, 0, "publish", "success"), True)
t("replay, same date, attempt 0", ("p3", d, 0, "replay", "success"), True)
t("daily attempt 1", ("d1", d, 1, "daily", "failed"), True)
t("duplicate daily attempt 1, same date", ("d1b", d, 1, "daily", "failed"), False)
t("daily attempt 2, same date", ("d2", d, 2, "daily", "success"), True)
t("other date attempt 1", ("d3", "2026-11-03", 1, "daily", "success"), True)
t("running row", ("r1", "2026-11-04", 1, "daily", "running"), True)
t("second running row (lock)", ("r2", "2026-11-05", 1, "daily", "running"), False)
t("running publish row also blocked by the lock", ("r3", "2026-11-05", 0, "publish", "running"), False)
t("ck_runs_attempt: publish with attempt 1", ("x1", "2026-11-06", 1, "publish", "success"), False)
t("ck_runs_attempt: daily with attempt 0", ("x2", "2026-11-06", 0, "daily", "success"), False)
print("RESULT:", "FAIL" if fails else "PASS")
sys.exit(1 if fails else 0)
