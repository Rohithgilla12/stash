# Stash Landing Site — Design Spec

**Date:** 2026-06-23
**Goal:** A marketing landing site for Stash that drives downloads — the top-of-funnel growth lever for the public beta.
**Status:** Design approved (pending final spec review).

---

## Context

Stash is a mature native macOS menu-bar productivity app (clipboard history, snippets/text-expansion, tasks with NL quick-add + recurrence + reminders, sticky notes, window snapping, focus timer, AI tab, command palette, MCP server). It ships a public beta via notarized DMG + Sparkle auto-update (GitHub Releases). It has **no marketing web presence** — discovery and download are the gap.

This project is **web work**, separate from the Swift app, living in the same repo.

## Audience & tone

- **Who:** Mac power users / developers / productivity enthusiasts evaluating a clipboard-manager / productivity tool (the Raycast / Paste / Alfred / Maccy crowd).
- **Job:** "Is this worth installing?" → understand the value fast → download.
- **Tone:** warm, calm, crafted, premium-Mac-app. Confident, not loud. Reads like a Things / Bear / Raycast product page.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Stack | **Astro** (static output), hand-crafted CSS with design tokens (no Tailwind) |
| Location | `/site` directory in this repo (monorepo) |
| Structure | **Scrolling feature tour** — hero → one section per pillar → download |
| Aesthetic | **Warm editorial, light** — warm off-white canvas, terracotta accent, big framed screenshots, generous whitespace, subtle scroll reveals |
| Deploy | **Cloudflare Pages + Workers**, automatic CI/CD via Cloudflare's Git integration. **No deploy config added to the repo** (no Actions workflow, no adapter, no deploy hooks). Standard portable static build. |
| Domain | Cloudflare-managed; chosen later by the user. Site must not hardcode an absolute domain (use relative URLs + a single `site` config value). |

## Brand / employer constraint

Never reference the user's employer anywhere on the site. "Made by" credits use the personal identity only (e.g. a GitHub link to `Rohithgilla12`). No "fusang".

---

## Page structure (top → bottom)

1. **Nav (minimal, sticky-on-scroll)** — "Stash" wordmark left; right: "Features", "GitHub", and a small **Download** button. Transparent over hero, gains a subtle warm background on scroll.

2. **Hero** —
   - Wordmark + one-line value prop: *"Your menu-bar command center — clipboard, notes, tasks & snippets, a keystroke away."* (final copy TBD in build).
   - Primary CTA **Download for macOS**; microcopy beneath: "macOS 14+ · free · auto-updates".
   - Secondary text link "View on GitHub".
   - Large device-framed hero screenshot (the hub popover or paste browser), with a subtle "lives up here ↑" menu-bar cue.

3. **Pillar sections** — reusable `FeatureSection`, alternating `imageSide` left/right for rhythm. Each: eyebrow label, short headline, 1–2 sentence copy, a framed screenshot, and the relevant hotkey chip. Order:
   1. **Clipboard history** — searchable history, ⌘1–9 quick-paste, link/OG previews, image clips, QR, transforms.
   2. **Snippets & text expansion** — triggers expand anywhere; dynamic placeholders (`{date}`, `{clipboard}`, `{cursor}`) + fill-in fields.
   3. **Tasks** — natural-language quick-add ("pay rent fri 9am !high"), recurring tasks, due reminders.
   4. **Sticky notes & notes** — desktop stickies + a notes window, persisted.
   5. **Window management** — keyboard snapping via Accessibility.
   6. **Focus timer** — Pomodoro in the menu bar.
   7. **AI + command palette** — ⌘K palette; AI tab.

4. **"Works your way"** — global hotkeys + `stash://` deeplinks (wire into Raycast / Karabiner). Power-user hook.

5. **Privacy** — local-first (SQLite on-device), per-app clipboard ignore-list, no account required. Builds trust.

6. **Download CTA (repeat)** — large download button + "auto-updates via Sparkle" + system requirements.

7. **Footer** — GitHub, changelog/releases link, current version, "made by" (personal GitHub).

## Visual system (warm editorial, light)

- **Color (OKLCH, tinted neutrals toward the brand hue):**
  - Canvas: warm off-white (~`oklch(0.98 0.008 60)`), never pure white.
  - Ink: warm near-black (~`oklch(0.26 0.02 60)`), never pure black.
  - Accent: terracotta `#c8642f` (the app accent), used at ~10% weight — CTAs, links, a few highlighted words. Reduce chroma at light/dark extremes.
  - Surfaces/hairlines: warm tints of the canvas.
- **Type:** a characterful **editorial display** face + a **clean warm body**, chosen via the impeccable font procedure — explicitly avoiding the banned list (Inter, Fraunces, Newsreader, Syne, etc.). Starting pair to validate in build: **Bricolage Grotesque** (display) + **Hanken Grotesk** (body). **Self-hosted** (no font CDN). Modular scale, ≥1.25 ratio, fluid `clamp()` on headings; body capped ~70ch.
- **Screenshots:** framed in soft rounded "window" chrome (warm shadow, subtle border). Mostly light-mode shots; one dark-mode shot for contrast (e.g. the paste browser).
- **Motion:** subtle scroll-reveal (fade + small rise), ease-out, **no bounce**; honors `prefers-reduced-motion`. One well-orchestrated hero entrance.
- **Spacing:** 4pt scale, semantic tokens, generous and asymmetric section rhythm. No card-grid monotony; not everything in a card.
- Avoid AI-slop tells: no gradient text, no left-border accent stripes, no glassmorphism-everywhere, no purple/cyan-on-dark.

## Architecture

```
/site
  package.json            # astro + dev deps only
  astro.config.mjs        # output: 'static'; site set to a placeholder, relative links
  src/
    pages/index.astro     # the one page, composes sections
    components/
      Nav.astro
      Hero.astro
      FeatureSection.astro # props: eyebrow, title, body, hotkey, image, imageSide
      WorksYourWay.astro
      Privacy.astro
      DownloadCTA.astro
      Footer.astro
    styles/
      tokens.css          # color/space/type custom properties
      global.css
    data/
      features.ts         # the pillar content (single source of truth, drives FeatureSection list)
    assets/               # framed screenshots (optimized)
  public/                 # favicon, og image, static files
```

- **Components are small and single-purpose.** `FeatureSection` is the one reusable unit; all pillars are data in `features.ts`.
- **No backend, no client framework.** Plain Astro + a tiny bit of vanilla JS for scroll-reveal (IntersectionObserver) and nav-on-scroll.

## Download mechanism

- v1: the **Download for macOS** button links to a stable, always-current DMG. Two options (decide in plan):
  - **(Recommended) Stable asset:** add a one-line step to `release.yml` to also upload a version-agnostic `Stash.dmg` copy → button links to `https://github.com/Rohithgilla12/stash/releases/latest/download/Stash.dmg` (direct download, never stale, no build-time network). This is a release-pipeline change, **not** a Cloudflare/deploy change.
  - **Fallback (zero repo change):** link to `https://github.com/Rohithgilla12/stash/releases/latest` (the releases page — one extra click).
- The version string + changelog link in the footer can be hardcoded for v1 (cheap) and revisited later.

## Accessibility, responsive, performance

- Mobile-first; fluid layout (the tour stacks to single-column on narrow screens; images never overflow). Body never scrolls horizontally.
- Semantic HTML, alt text on every screenshot, visible focus states, WCAG AA contrast (verify the terracotta-on-warm combos).
- `prefers-reduced-motion` disables reveals.
- Self-hosted fonts with `font-display: swap`; compressed images (Astro asset pipeline); target a high Lighthouse score (static site → easy).

## Assets

- Capture **fresh, clean** light screenshots for each pillar (hub popover, paste browser w/ ⌘N badges, snippets editor + fill-in form, tasks with NL/recurrence/reminder, stickies, command palette) + one dark shot. Frame them consistently. **This is the bulk of the manual work** and a real dependency for the build.

## Verification

- `npm run build` (astro) succeeds; no broken internal links.
- Responsive check mobile → desktop; reduced-motion check.
- Download link resolves to a real DMG (or releases page).
- Publish an **Artifact preview** of the built page for the user to review **before** they point a domain at it.

## Out of scope (YAGNI for v1)

- Changelog page / blog / MDX content collections (Astro leaves room; add later).
- Analytics, waitlist, forms, accounts, team features.
- i18n.
- Any Cloudflare-specific code, adapters, or CI/CD config (the user owns deploy via CF Git integration).

## Open choices for the plan

1. Download button: stable `Stash.dmg` asset (recommended) vs releases-page link.
2. Final font pair (validate Bricolage Grotesque + Hanken Grotesk during build via the impeccable procedure).
3. Exact hero/section copy (drafted during build).
