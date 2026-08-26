# Rx Manager

A personal medication list & refill manager, built as an offline-capable web app
(PWA) intended to run on an iPad in landscape as a dedicated/kiosk device.

## Features
- **Medication list** with "Action Required" (overdue / order-now / renew) and
  days-on-hand tracking, filterable by drug class.
- **Two users** — switch between profiles (e.g. GAGE / KAYLENE); each has its
  own list.
- **Lead Times** screen — the refill-timing constants (mail-order lead, renewal
  lead, controlled/cold-chain add-ons, overdue threshold) and the order-by
  formula.
- **Add / Scan** flows.
- **Runs fully offline** after first load (service worker caches everything).
- Data you enter lives in the browser's `localStorage` on that device only — it
  is never uploaded or committed to this repo.

## Repo layout
| Path | What it is |
|------|------------|
| `docs/` | The deployable site — **GitHub Pages serves from here**. Self-contained: vendored React/ReactDOM/Babel (`docs/vendor/`) and IBM Plex Mono fonts (`docs/fonts/`), so there are **no external network dependencies**. |
| `design/` | The editable Claude Design source (`*.dc.html`) + its runtime (`support.js`) and the source spreadsheet. `Med Manager v3.dc.html` is the current design. |

## Deploy with GitHub Pages
1. Repo → **Settings → Pages**.
2. **Source:** *Deploy from a branch*.
3. **Branch:** `main`, **Folder:** `/docs`. Save.
4. Wait ~1 min; your site appears at `https://<user>.github.io/<repo>/`.

The `docs/.nojekyll` file disables Jekyll so every asset is served verbatim.

## Add to an iPad (kiosk)
1. iPad → latest iPadOS. Open the Pages URL in **Safari**, let it fully load once
   (this caches it for offline).
2. **Share → Add to Home Screen** → launches fullscreen (no Safari chrome).
3. Lock to this app: **Settings → Accessibility → Guided Access → On**, then open
   the app and **triple-click the Home button → Start**.
4. Use the iPad in **landscape** (turn on rotation lock).

## Updating the app
1. Edit the design in Claude Design and re-export, or edit files under `docs/`.
2. **Bump `CACHE_VERSION`** in [`docs/sw.js`](docs/sw.js) (e.g. `rx-manager-v4`)
   so devices pick up the new build instead of serving the old cache.
3. Commit and push — GitHub Pages redeploys automatically.

## Offline / vendored dependencies
The design runtime normally loads React, ReactDOM, and Babel from a CDN and fonts
from Google. Those are vendored locally under `docs/vendor/` and `docs/fonts/`,
and the app is redirected to them via `window.__resources` (set in
`docs/index.html`). The service worker (`docs/sw.js`) precaches the full asset
list.
