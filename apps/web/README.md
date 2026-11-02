# apps/web

Next.js dashboard `meridian-web` (App Router, TypeScript, `next-drupal`). Empty until T21.
Theme tokens and assets follow `docs/TASKS.md` section 0b: self-hosted Fira Sans, SVG
icons only, WebP images, no third-party hosts.

Runs in the DDEV container `meridian-web` (Node 22, from T06). Use `ddev next <command>`.
`https://meridian.ddev.site:3001` serves a placeholder until T21; T21 adds `package.json` and
the container then runs `npm run dev` with no compose change.
