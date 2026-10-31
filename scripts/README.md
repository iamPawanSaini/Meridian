# scripts

Repository tooling. Every script runs from any directory inside the repo.

| Script | Purpose |
|---|---|
| `bootstrap-dev.sh` | Installs pinned pre-commit into `.tools/` (git-ignored) and installs the git hooks |
| `tool-versions.env` | Pinned tool versions and checksums used by the bootstrap |
| `check-names.sh` | Fails if a stale placeholder project name appears (section 0 naming) |
| `demo-secret-scan.sh` | Shows, in a throwaway repo, that a commit containing a fake key is rejected (T00 evidence) |
