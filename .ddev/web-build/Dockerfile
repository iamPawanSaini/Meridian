# T07: pin Terminus 4.x in the DDEV web image.
# The DDEV v1.24.4 web image ships Terminus 3.6.2. With a Pantheon personal access token (PAT,
# issued since 2026-09-30) its `auth:login` fails with "HTTP request POST .../api/authorize/
# machine-token has failed with error Undefined" and "Maximum retry attempts reached", while the
# Pantheon API is reachable. Terminus 4.x authenticates with the PAT.
#
# Pin record (CODING_STANDARDS, pinned versions):
#   version  4.3.3 (latest release, published 2026-08-20)
#   source   https://github.com/pantheon-systems/terminus/releases/tag/4.3.3 (asset terminus.phar)
#   sha256   e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade
#   checked  2026-11-02: the digest GitHub shows for the asset equals the sha256sum of the
#            downloaded file
# To upgrade: change both ARG values in a task with a plan entry, then `ddev debug rebuild -s web`.
ARG TERMINUS_VERSION=4.3.3
ARG TERMINUS_SHA256=e7ca9bcad3acbb1cfc0cec32550eeb2351e578dc6d5f79cd3a5303201893bade

# The checksum is verified from a file, not a pipe, so a failure stops the build. The phar
# replaces the one DDEV installs at the same path, so `terminus` on PATH is always this version.
RUN curl -fsSL -o /tmp/terminus.phar \
      "https://github.com/pantheon-systems/terminus/releases/download/${TERMINUS_VERSION}/terminus.phar" \
 && printf '%s  %s\n' "${TERMINUS_SHA256}" /tmp/terminus.phar >/tmp/terminus.phar.sha256 \
 && sha256sum --check --strict /tmp/terminus.phar.sha256 \
 && install -m 0755 /tmp/terminus.phar /usr/local/bin/terminus \
 && rm -f /tmp/terminus.phar /tmp/terminus.phar.sha256 \
 && [ "$(terminus --version)" = "Terminus ${TERMINUS_VERSION}" ]
