# TC-T02-34 live spot-check of cited claims (main session, 2026-11-01)

Executed by the main session through a web-fetch agent, because the tester agent has no web
tool. Four claims from the risk register and cost map were compared with their cited pages.

| # | Claim in T02 docs | Source | Verdict | Page text (verbatim unless noted) |
|---|---|---|---|---|
| 1 | RK-09: Vercel Hobby is non-commercial personal use only; usage over a limit pauses the feature until 30 days pass | https://vercel.com/docs/plans/hobby (page updated 2026-09-14) | Supported in substance | "the Hobby plan restricts users to non-commercial, personal use only." / "In most cases, if you exceed your usage limits on the Hobby plan, you will have to wait until 30 days have passed before you can use the feature again." Note: "in most cases"; Web Analytics resumes after 7 days. |
| 2 | RK-04: Pantheon containers sleep after about 1 h idle and wake in about 30 s; remote MySQL/SFTP fail while idle | https://docs.pantheon.io/application-containers (page last reviewed 2020-04-24) | Supported | "Pantheon containers spin down (sleep) after ~1 hour of idle time." / "spun up, usually within 30 seconds." / "Attempts to remotely access services (such as MySQL or SFTP connections) will fail on idle containers." |
| 3 | RK-05: `schedule` can be delayed under high load and queued jobs dropped; public-repo schedules disabled after 60 days without activity | https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows | Supported (quotes from fetch summary; page truncated) | "can be delayed during periods of high loads" / "some queued jobs may be dropped" / "automatically disabled when no repository activity has occurred in 60 days" |
| 4 | Cost map: Neon Free 1 GB storage per project, 100 CU-hours/month, scale to zero after 5 min | https://neon.com/faqs/free-plan-limits-and-quotas (page updated 2026-10-01) | Supported | "100 CU-hours of compute per project per month" / "1 GB of Postgres storage per project" / "Computes scale to zero after 5 minutes of inactivity" |

Result: 4 of 4 supported in substance. Minor wording note for RK-09 ("in most cases") raised
as an observation, not a defect. Pantheon page is old (2020); T07 re-confirms sleep behaviour.
