#!/usr/bin/env bash
# T06: build a CA bundle (system CAs plus the DDEV mkcert root) so Python trusts
# https://meridian.ddev.site, then run the container command. T13 may move this into its Dockerfile.
set -euo pipefail

bundle=/tmp/meridian-ca-bundle.pem
root=/mnt/ddev-global-cache/mkcert/rootCA.pem

cat /etc/ssl/certs/ca-certificates.crt >"$bundle"
if [[ -r "$root" ]]; then
  cat "$root" >>"$bundle"
else
  echo "meridian-engine: mkcert root $root not found; run 'mkcert -install' on the host" >&2
fi
exec "$@"
