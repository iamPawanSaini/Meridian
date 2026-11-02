# T07: Terminus 4.3.3 source facts

| Field | Value |
|---|---|
| Version | Terminus 4.3.3 (`terminus --version` in the DDEV web container) |
| Release | `https://github.com/pantheon-systems/terminus/releases/tag/4.3.3` |
| Phar sha256 | `e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade` (pinned in `.ddev/web-build/Dockerfile` and `deploy-drupal.yml`) |
| Checked | 2026-11-02 |
| How | The pinned phar was copied to a `.phar` name in the web container and extracted with PHP's `Phar::extractTo`. The files below were read. Paths are relative to the phar's `src/`. No credentials and no network call to Pantheon were used |

These facts back the unverified-register row in `docs/architecture/technical-design.md` and
review findings 1, 2 and 10. Items marked "live" are still checked by `/test-task` (review items
L-2, L-4, L-5).

| # | File and method | Fact | Used by |
|---|---|---|---|
| a | `Commands/Remote/SSHBaseCommand.php`, `getConnectionString()` | The string is `<ssh_command> -T <user>@<host> -p <port> -o "StrictHostKeyChecking=no" -o "AddressFamily inet"`. The configured `ssh_command` (`TERMINUS_SSH_COMMAND`) comes **first**; `StrictHostKeyChecking=no` is appended after it. OpenSSH takes the first value of an option, so an option set in `ssh_command` wins. Drush (app server) is therefore not strict unless `ssh_command` says so, which matches SA-4 (deliberately unpinned) | `TERMINUS_SSH_COMMAND` in the script |
| b | `Commands/Workflow/WaitCommand.php`, `waitForCommit()` | With `--commit` it reads `sites/<id>/logs/workflows` and keeps entries whose `workflow->environment` equals the environment, whose `target_commit` starts with the SHA and whose `started_at >= --start`. It takes the newest and polls until status is `Success`, `Failed` or `Aborted`. Any status other than `Success` throws `TerminusException` (non-zero exit). On success it logs the notice `Workflow <id> completed successfully for commit <sha>` | stage 6 |
| c | same, `waitForCommit()` | Exit 0 **without** success in two cases: timeout (warning `Waited '<n>' seconds, giving up waiting ...`) and no matching workflow after 10 tries of 5 s (warning `Workflow with commit <sha> not found after 10 attempts.`). So the script requires the success line, not only exit 0 | stage 6 |
| d | same, `workflowWait()` | `--start` defaults to `time() - 60`. A re-run of an old commit finds nothing with the default, so the re-run passes `--start=1` to match the earlier workflow. A failed earlier workflow of the same SHA is the newest match and throws | finding 1 (re-run path) |
| e | `Commands/Auth/LoginCommand.php`, `logIn()` | The PAT is read only from `--machine-token` (and `--email` for a saved token). There is no environment variable path in the command | choice A3 (`--machine-token`) |
| f | `Commands/Auth/WhoamiCommand.php`, `whoAmI()` | Logged out: logs the notice `You are not logged in.` (stderr) and returns nothing, exit **0**. Seen in the container with `auth:whoami --field=email` after `auth:logout`: exit 0, empty stdout. The script therefore tests that stdout holds an email | finding 2 |
| g | `terminus help workflow:list` | The fields are id, env, workflow, user, status, started_at, finished_at, time. There is **no commit** field, so the list cannot be filtered by commit. This is why `workflow:wait --commit` was chosen over `workflow:list` plus `workflow:info:status` | finding 1 mechanism |
| h | `Commands/Env/CodeLogCommand.php`, `Models/Commit.php` | Output rows have a `hash` field. Newest first is a live check (L-5) | stage 6 `env:code-log` |

Upgrade path: when `TERMINUS_VERSION` changes, re-read items b to d and f, and re-run the unit
tests in `scripts/tests/test_deploy_drupal.py`.
