#!/usr/bin/env bash
# T06: start the meridian-web container process. T21 owns the dev branch of this script.
# With apps/web/package.json (from T21) it runs the Next.js dev server; before that it serves
# the T06 placeholder on 0.0.0.0:3000.
set -euo pipefail

cd /var/www/html/apps/web
if [[ -f /var/www/html/apps/web/package.json ]]; then
  exec npm run dev -- --hostname 0.0.0.0 --port 3000
fi
exec node /var/www/html/.ddev/meridian-web/placeholder-server.mjs
