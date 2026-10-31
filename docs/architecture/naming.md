# Naming and branding check: "Meridian"

| Field | Value |
|---|---|
| Task | T02 |
| Author | solution-architect |
| Date | 2026-11-01 |
| Scope | Domains, code-hosting and hosting handles, Indian trademark register, app stores, repo name |

`docs/TASKS.md` section 0 fixes "Meridian" as the project name, and flags the name risk:
"Meridian" is a common word. This check decides whether the name can be used publicly,
should stay internal, or must change.

This is an agent check, not legal clearance. Several checks cannot be done reliably by an
agent. Those are marked "not verifiable by agent" and become owner actions (OA-n below).

## Checks

| # | Check | Method | Source | Date | Result |
|---|---|---|---|---|---|
| 1 | `.com` domain (`meridian.com`) | HTTPS request by the agent | https://meridian.com | 2026-11-01 | The name resolves to an address (connection to 216.21.224.199:443 refused), so the domain is registered by someone else. Treat it as **not available**. Registrant and any sale status are not verifiable by agent (OA-1) |
| 2 | `.in` domain (`meridian.in`) | HTTPS request by the agent | https://meridian.in | 2026-11-01 | The remote closed the connection, so the result is inconclusive. It probably resolves, which means it is registered. Not verifiable by agent (OA-1) |
| 3 | GitHub handle `meridian` | Fetched the profile page | https://github.com/meridian | 2026-11-01 | **Taken**: an existing user account with no public repositories. `meridian-web` is also a taken user handle (https://github.com/meridian-web). The project does not need the handle, because the repo lives under the owner's account |
| 4 | GitHub repo name: `Meridian` vs section 0 `meridian` (T00 review finding 2) | Compared the repo and folder name with section 0. Read the GitHub rename docs | https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository | 2026-11-01 | **Mismatch confirmed**: the repo and folder are `Meridian`, while section 0 says `meridian`. After a rename, GitHub redirects web traffic and `git clone`, `fetch` and `push` against the old name, but recommends `git remote set-url`. The rename is an owner action (OA-5) |
| 5 | Vercel handle (`meridian.vercel.app`, team slug `meridian`) | Fetched the project URL and the team URL | https://meridian.vercel.app | 2026-11-01 | `meridian.vercel.app` is **taken** and serves an unrelated placeholder site. https://vercel.com/meridian shows the login page, so team-slug availability is not verifiable by agent. Dev uses the Vercel-assigned project URL for `meridian-web`. No custom handle is needed |
| 6 | IP India trademark register, classes 9, 36 and 42 | The public search is form-based, so it is not verifiable by agent. The agent ran a web search for leads | https://ipindiaonline.gov.in/tmrpublicsearch/ | 2026-11-01 | Not verifiable by agent (OA-2). Leads from a third-party aggregator (**unverified**): a class 36 application for the word mark "Meridian One Alpha" (No. 7997688, status "Ready for Examination", financial and investment advisory services), listed at https://www.registerkaro.in/trademark-search/meridian-one-alpha-7997688 (fetch returned 403). No Indian class 9 or 42 "Meridian" mark was found by web search |
| 7 | Same-niche product search ("Meridian" AI stock research, India, NSE) | Web search | https://www.producthunt.com/products/pe-tech-knowledge-nse-stock-research | 2026-11-01 | No product named Meridian was found among Indian AI stock-research tools. Similar tools exist under other names. Outside India, "MERIDIAN" marks exist for investment and trading software, for example a US record at https://trademarks.justia.com/863/50/meridian-86350091.html, and a UK class 9 filing for financial trading software by a trading firm |
| 8 | Google Play Store search | Not verifiable by agent: the store search is dynamic and region-dependent | https://play.google.com/store/search?q=Meridian&c=apps | 2026-11-01 | Not verifiable by agent (OA-3) |
| 9 | Apple App Store search | Not verifiable by agent: there is no web search for the App Store | https://apps.apple.com/in/ | 2026-11-01 | Not verifiable by agent (OA-4) |

## Assessment

- The `.com`, GitHub and Vercel names are taken. The `.in` result is inconclusive.
- Common-word marks in finance and software exist abroad. An Indian class 36 application
  contains "Meridian".
- Nothing found blocks **internal** use: repo, package and service names that never face the
  public.
- Public use would need a trademark search with a lawyer's reading in classes 9, 36 and 42,
  plus a distinctive qualifier or a different name.
- Meridian is private and non-commercial (solution architecture A-02 and A-03). Renaming now
  would churn names across the repo for no present benefit.

## Decision

**Outcome:** keep as internal codename only.

Consequences:

- The section 0 names stay as they are, so `docs/TASKS.md` does not change and
  `scripts/check-names.sh` needs no update.
- "Meridian" must not appear as a public brand on any public page, store listing, domain or
  marketing material until OA-1 to OA-4 are closed and the decision is revisited.
- The decision is revisited at T33 (go/no-go), or earlier if the project ever goes public.
  This is tracked as OQ-10 in the solution architecture.

## Owner actions

Record each result in this file with the date, the search term and a screenshot or a copied
result list under `docs/tests/T02/evidence/`.

1. **OA-1 Domains (WHOIS and registrar).** Open https://lookup.icann.org/en/lookup and look
   up `meridian.com` and `meridian.in`. For `.in`, if ICANN Lookup returns nothing, use the
   .IN registry WHOIS linked from https://www.registry.in. Record the registrant
   organisation (or "redacted"), the creation and expiry dates and the status. Then check
   availability and any aftermarket price at one registrar of your choice.
2. **OA-2 IP India trademark search.**
   - Open https://ipindiaonline.gov.in/tmrpublicsearch/ (if it has moved, start from
     https://ipindia.gov.in and follow "Trade Marks", then "Public Search").
   - Run a **Wordmark** search with "Meridian", match type "Contains", once each for
     **class 9**, **class 36** and **class 42**.
   - Repeat as a **Phonetic** search for the same three classes.
   - For every hit, record the application number, mark, class, proprietor, status and
     goods or services.
   - Specifically confirm or dismiss application No. 7997688 ("Meridian One Alpha",
     class 36).
3. **OA-3 Google Play.** On https://play.google.com/store/search?q=Meridian&c=apps, signed in
   with the store country set to India, search for "Meridian" and then "Meridian stock".
   Record every app named Meridian in the finance or investing category: developer, installs
   and description.
4. **OA-4 Apple App Store.** On an iPhone or iPad with the India storefront, search the App
   Store for "Meridian" and then "Meridian stock". Record finance or investing apps named
   Meridian: developer and description.
5. **OA-5 Repo name.** On GitHub, open the repository's Settings and rename `Meridian` to
   `meridian`. Then run `git remote set-url origin <new URL>` in each clone, and rename the
   local folder to `meridian` if wanted. Record the date here and close T00 review finding 2.
