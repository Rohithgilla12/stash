# Stash Landing Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A warm-editorial, scrolling-feature-tour marketing landing site for Stash that drives macOS downloads.

**Architecture:** A static **Astro** site in `/site` (no client framework, no backend). One page (`index.astro`) composed of small single-purpose components; all pillar content lives in one data file (`features.ts`) driving a reusable `FeatureSection`. Hand-crafted CSS with design tokens (no Tailwind). A few lines of vanilla JS for scroll-reveal + nav-on-scroll. Self-hosted fonts via Fontsource. Verification is `astro build` + grepping the built HTML.

**Tech Stack:** Astro (static output), vanilla CSS + custom properties, Fontsource fonts, `sharp` (Astro image optimization). Node 20+.

## Global Constraints

- **Deploy-agnostic:** add NO deploy config to the repo — no GitHub Actions workflow, no Astro SSR adapter, no Cloudflare files, no deploy hooks. `output: 'static'` only. The user deploys via Cloudflare Pages Git integration (root `/site`, build `npm run build`, output `dist`).
- **No employer name anywhere.** "Made by" credit links only to GitHub `Rohithgilla12`. Never "fusang".
- **Fonts self-hosted** (no font CDN). Avoid the banned AI-tell fonts (Inter, Roboto, Fraunces, Newsreader, Syne, DM Sans, Space Grotesk, etc.). Use **Bricolage Grotesque** (display) + **Hanken Grotesk** (body) via Fontsource.
- **Colors in OKLCH**, warm neutrals tinted toward terracotta; accent `#c8642f` used sparingly. No pure black/white. No gradient text, no left-border accent stripes, no glassmorphism-everywhere.
- **Accessibility:** semantic HTML, alt text on every image, visible focus, WCAG AA contrast, honor `prefers-reduced-motion`.
- **Relative URLs only**; `site` in `astro.config.mjs` is a placeholder the user changes — do not hardcode a production domain in markup.
- Work happens in `/site`; do not modify the Swift app. The only allowed repo change outside `/site` is the optional `release.yml` step in Task 7 (gated on the user's choice).

---

### Task 1: Scaffold Astro project + design tokens + fonts

**Files:**
- Create: `site/package.json`, `site/astro.config.mjs`, `site/tsconfig.json`, `site/.gitignore`
- Create: `site/src/styles/tokens.css`, `site/src/styles/global.css`
- Create: `site/src/layouts/Base.astro`
- Create: `site/src/pages/index.astro` (temporary smoke content)

**Interfaces:**
- Produces: `Base.astro` layout (props: `title: string`, `description: string`) wrapping `<slot/>` with `<head>` meta + global styles + font imports; the CSS custom properties in `tokens.css` (e.g. `--canvas`, `--ink`, `--accent`, `--space-*`, `--font-display`, `--font-body`, type-scale vars).

- [ ] **Step 1: Create `site/package.json`**

```json
{
  "name": "stash-site",
  "type": "module",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview"
  },
  "dependencies": {
    "astro": "^4.16.0",
    "sharp": "^0.33.5",
    "@fontsource/bricolage-grotesque": "^5.1.0",
    "@fontsource-variable/hanken-grotesk": "^5.1.0"
  }
}
```

- [ ] **Step 2: Create `site/astro.config.mjs`**

```js
import { defineConfig } from 'astro/config';

// `site` is a placeholder — the user sets the real domain in Cloudflare.
// Static output only; no deploy adapter (deploy is Cloudflare's job).
export default defineConfig({
  site: 'https://stash.example',
  output: 'static',
  build: { assets: 'assets' },
});
```

- [ ] **Step 3: Create `site/.gitignore` and `site/tsconfig.json`**

`site/.gitignore`:
```
node_modules/
dist/
.astro/
```

`site/tsconfig.json`:
```json
{ "extends": "astro/tsconfigs/strict" }
```

- [ ] **Step 4: Create `site/src/styles/tokens.css`**

```css
:root {
  /* Warm editorial palette (OKLCH, neutrals tinted toward terracotta) */
  --canvas: oklch(0.98 0.008 60);
  --surface: oklch(0.965 0.012 60);
  --ink: oklch(0.26 0.02 55);
  --ink-soft: oklch(0.46 0.02 55);
  --ink-faint: oklch(0.60 0.018 55);
  --hairline: oklch(0.90 0.012 60);
  --accent: oklch(0.62 0.15 47);        /* ~ #c8642f */
  --accent-strong: oklch(0.55 0.16 47);
  --accent-tint: oklch(0.95 0.03 55);

  /* Spacing — 4pt scale */
  --space-2: 0.5rem;  --space-3: 0.75rem; --space-4: 1rem;
  --space-6: 1.5rem;  --space-8: 2rem;    --space-12: 3rem;
  --space-16: 4rem;   --space-24: 6rem;   --space-32: 8rem;

  /* Type */
  --font-display: 'Bricolage Grotesque', system-ui, sans-serif;
  --font-body: 'Hanken Grotesk Variable', system-ui, sans-serif;
  --step-0: 1rem;
  --step-1: 1.25rem;
  --step-2: clamp(1.5rem, 1.2rem + 1.5vw, 2rem);
  --step-3: clamp(2rem, 1.5rem + 2.5vw, 3rem);
  --step-4: clamp(2.75rem, 2rem + 4vw, 4.5rem);

  --maxw: 1100px;
  --radius: 14px;
}
```

- [ ] **Step 5: Create `site/src/styles/global.css`**

```css
@import '@fontsource/bricolage-grotesque/400.css';
@import '@fontsource/bricolage-grotesque/600.css';
@import '@fontsource/bricolage-grotesque/800.css';
@import '@fontsource-variable/hanken-grotesk';
@import './tokens.css';

* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }

body {
  margin: 0;
  background: var(--canvas);
  color: var(--ink);
  font-family: var(--font-body);
  font-size: var(--step-0);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}
h1, h2, h3 { font-family: var(--font-display); line-height: 1.05; font-weight: 800; letter-spacing: -0.01em; margin: 0; }
p { margin: 0; }
a { color: var(--accent-strong); }
img { max-width: 100%; height: auto; display: block; }
.container { width: 100%; max-width: var(--maxw); margin-inline: auto; padding-inline: var(--space-6); }
:focus-visible { outline: 2px solid var(--accent-strong); outline-offset: 3px; border-radius: 4px; }

/* Shared, cross-component classes MUST live here — Astro scopes <style> per
   component, so these would not apply if defined inside one component. */
.btn { display: inline-block; padding: var(--space-3) var(--space-6); border-radius: 999px; font-weight: 600; text-decoration: none; }
.btn--primary { background: var(--accent); color: #fff; }
.btn--ghost { color: var(--ink); border: 1px solid var(--hairline); }
.frame { border-radius: var(--radius); overflow: hidden; border: 1px solid var(--hairline); box-shadow: 0 30px 60px -30px oklch(0.4 0.05 55 / 0.35); background: var(--surface); margin: 0; }
.feat__eyebrow { color: var(--accent-strong); font-weight: 600; text-transform: uppercase; letter-spacing: 0.06em; font-size: 0.8rem; }
.hero__meta { color: var(--ink-faint); font-size: 0.9rem; margin-top: var(--space-3); }
```

> **Astro style-scoping rule (applies to Tasks 2–4):** the classes above are GLOBAL. In the component `<style>` blocks below, do NOT redefine `.btn*`, `.frame`, `.feat__eyebrow`, or `.hero__meta` — keep only component-unique selectors (e.g. `.hero__title`, `.feat__title`, `.download__title`). The hero frame's top margin (`margin-top: var(--space-16)`) stays as a Hero-scoped rule on the `.frame` element via an extra class or inline style, since `.frame` itself is shared.

- [ ] **Step 6: Create `site/src/layouts/Base.astro`**

```astro
---
import '../styles/global.css';
interface Props { title: string; description: string; }
const { title, description } = Astro.props;
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:type" content="website" />
  </head>
  <body>
    <slot />
  </body>
</html>
```

- [ ] **Step 7: Create temporary `site/src/pages/index.astro` (smoke test)**

```astro
---
import Base from '../layouts/Base.astro';
---
<Base title="Stash" description="Your menu-bar command center for macOS.">
  <main class="container"><h1>Stash</h1></main>
</Base>
```

- [ ] **Step 8: Install + build to verify the toolchain**

Run: `cd site && npm install && npm run build`
Expected: completes with "Complete!" and creates `site/dist/index.html`. Verify the page + fonts are wired:
Run: `grep -q "Stash" site/dist/index.html && ls site/dist/assets | grep -iE "bricolage|hanken" && echo OK`
Expected: prints `OK` (built HTML contains "Stash"; font files emitted to assets).

- [ ] **Step 9: Commit**

```bash
git add site/ && git commit -m "feat(site): scaffold Astro project + warm-editorial tokens + fonts"
```

---

### Task 2: Nav + Hero + page assembly

**Files:**
- Create: `site/src/components/Nav.astro`, `site/src/components/Hero.astro`
- Create: `site/src/assets/placeholder.svg` (stand-in screenshot until Task 6)
- Modify: `site/src/pages/index.astro`

**Interfaces:**
- Consumes: `Base.astro` from Task 1.
- Produces: `Nav.astro` (no props) and `Hero.astro` (no props) used by `index.astro`. A `data-reveal` attribute convention on elements that should animate in (wired in Task 5). The download URL constant `DOWNLOAD_URL` is finalised in Task 7 — for now use `https://github.com/Rohithgilla12/stash/releases/latest`.

- [ ] **Step 1: Create `site/src/assets/placeholder.svg`** — a neutral 1280×800 warm rectangle labelled "screenshot" so layout/build works before real assets land.

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="800" viewBox="0 0 1280 800">
  <rect width="1280" height="800" rx="16" fill="#f0e7df"/>
  <text x="640" y="400" font-family="sans-serif" font-size="28" fill="#b08a72" text-anchor="middle">screenshot</text>
</svg>
```

- [ ] **Step 2: Create `site/src/components/Nav.astro`**

```astro
---
const links = [
  { href: '#features', label: 'Features' },
  { href: 'https://github.com/Rohithgilla12/stash', label: 'GitHub' },
];
---
<header class="nav" id="site-nav">
  <div class="container nav__inner">
    <a class="nav__brand" href="#top">Stash</a>
    <nav class="nav__links">
      {links.map((l) => <a href={l.href}>{l.label}</a>)}
      <a class="nav__cta" href="#download">Download</a>
    </nav>
  </div>
</header>
<style>
  .nav { position: sticky; top: 0; z-index: 50; transition: background 0.2s ease, border-color 0.2s ease; border-bottom: 1px solid transparent; }
  .nav.is-scrolled { background: color-mix(in oklch, var(--canvas) 88%, transparent); backdrop-filter: blur(8px); border-bottom-color: var(--hairline); }
  .nav__inner { display: flex; align-items: center; justify-content: space-between; padding-block: var(--space-3); }
  .nav__brand { font-family: var(--font-display); font-weight: 800; font-size: var(--step-1); color: var(--ink); text-decoration: none; }
  .nav__links { display: flex; align-items: center; gap: var(--space-6); }
  .nav__links a { color: var(--ink-soft); text-decoration: none; font-weight: 500; }
  .nav__cta { background: var(--accent); color: #fff !important; padding: var(--space-2) var(--space-4); border-radius: 999px; }
  @media (max-width: 640px) { .nav__links a:not(.nav__cta) { display: none; } }
</style>
```

- [ ] **Step 3: Create `site/src/components/Hero.astro`** (uses the placeholder image + a framed `figure`)

```astro
---
import { Image } from 'astro:assets';
import shot from '../assets/placeholder.svg';
const DOWNLOAD_URL = 'https://github.com/Rohithgilla12/stash/releases/latest';
---
<section class="hero" id="top">
  <div class="container hero__inner">
    <p class="hero__eyebrow" data-reveal>Lives up here ↑ in your menu bar</p>
    <h1 class="hero__title" data-reveal>Your Mac, a keystroke away.</h1>
    <p class="hero__lede" data-reveal>Clipboard history, snippets, tasks, sticky notes, window snapping and more — one menu-bar app that keeps your day in reach.</p>
    <div class="hero__cta" data-reveal>
      <a class="btn btn--primary" href={DOWNLOAD_URL}>Download for macOS</a>
      <a class="btn btn--ghost" href="https://github.com/Rohithgilla12/stash">View on GitHub</a>
    </div>
    <p class="hero__meta" data-reveal>macOS 14+ · free · auto-updates</p>
    <figure class="frame" data-reveal>
      <Image src={shot} alt="The Stash menu-bar hub showing clipboard history" widths={[640, 1024, 1280]} sizes="(max-width: 900px) 100vw, 1000px" />
    </figure>
  </div>
</section>
<style>
  .hero__inner { padding-block: var(--space-24) var(--space-16); text-align: center; }
  .hero__eyebrow { color: var(--accent-strong); font-weight: 600; margin-bottom: var(--space-4); }
  .hero__title { font-size: var(--step-4); max-width: 14ch; margin-inline: auto; }
  .hero__lede { font-size: var(--step-1); color: var(--ink-soft); max-width: 56ch; margin: var(--space-6) auto 0; }
  .hero__cta { display: flex; gap: var(--space-3); justify-content: center; margin-top: var(--space-8); flex-wrap: wrap; }
  /* .btn*, .frame and .hero__meta are GLOBAL (see global.css). Only the hero's
     frame top-margin is hero-specific: */
  .hero .frame { margin-top: var(--space-16); }
</style>
```

- [ ] **Step 4: Update `site/src/pages/index.astro`**

```astro
---
import Base from '../layouts/Base.astro';
import Nav from '../components/Nav.astro';
import Hero from '../components/Hero.astro';
---
<Base title="Stash — your menu-bar command center for macOS" description="Clipboard history, snippets, tasks, sticky notes and window snapping in one fast macOS menu-bar app.">
  <Nav />
  <main><Hero /></main>
</Base>
```

- [ ] **Step 5: Build + verify content**

Run: `cd site && npm run build`
Then: `grep -qE "Download for macOS" site/dist/index.html && grep -q "menu bar" site/dist/index.html && echo OK`
Expected: `OK`. Manually confirm `npm run dev` renders a centered hero with two buttons + a framed placeholder.

- [ ] **Step 6: Commit**

```bash
git add site/ && git commit -m "feat(site): nav + hero with download CTA"
```

---

### Task 3: FeatureSection component + pillar data + the tour

**Files:**
- Create: `site/src/data/features.ts`
- Create: `site/src/components/FeatureSection.astro`
- Modify: `site/src/pages/index.astro`

**Interfaces:**
- Consumes: `placeholder.svg` (Task 2) for each feature image until Task 6.
- Produces: `Feature` type `{ id: string; eyebrow: string; title: string; body: string; hotkey?: string; image: ImageMetadata; }` and `features: Feature[]` (7 items). `FeatureSection.astro` props: `feature: Feature`, `index: number` (even = image right, odd = image left).

- [ ] **Step 1: Create `site/src/data/features.ts`** — single source of truth for the 7 pillars (image is the placeholder for now; swapped in Task 6).

```ts
import type { ImageMetadata } from 'astro';
import placeholder from '../assets/placeholder.svg';

export interface Feature {
  id: string; eyebrow: string; title: string; body: string; hotkey?: string; image: ImageMetadata; alt: string;
}

export const features: Feature[] = [
  { id: 'clipboard', eyebrow: 'Clipboard', title: 'Everything you copied, instantly back.', body: 'Searchable history with link previews, image clips and QR codes. Hit a number to paste — ⌘1–9.', hotkey: '⌃⌥V', image: placeholder, alt: 'Stash clipboard history browser' },
  { id: 'snippets', eyebrow: 'Snippets', title: 'Type less, everywhere.', body: 'Text-expansion triggers fire system-wide, with dynamic placeholders like {date}, {clipboard} and fill-in fields.', hotkey: ':trigger', image: placeholder, alt: 'Stash snippet editor with placeholders' },
  { id: 'tasks', eyebrow: 'Tasks', title: 'Plans in plain English.', body: 'Type “pay rent fri 9am !high” and Stash sets the date, time and priority. Recurring tasks and due reminders included.', image: placeholder, alt: 'Stash tasks with natural-language quick-add' },
  { id: 'stickies', eyebrow: 'Sticky notes', title: 'Notes that stay in sight.', body: 'Drop sticky notes on your desktop or jot in the notes window — all persisted.', hotkey: '⌃⌥S', image: placeholder, alt: 'Stash sticky notes on the desktop' },
  { id: 'windows', eyebrow: 'Windows', title: 'Snap without the mouse.', body: 'Keyboard-driven window tiling powered by Accessibility — halves, corners, fullscreen.', image: placeholder, alt: 'Stash window snapping' },
  { id: 'focus', eyebrow: 'Focus', title: 'A timer in your menu bar.', body: 'Pomodoro sessions that count down right where you can see them.', image: placeholder, alt: 'Stash focus timer in the menu bar' },
  { id: 'ai', eyebrow: 'AI & palette', title: 'Command everything with ⌘K.', body: 'A fuzzy command palette for every action, plus an AI tab to put your day in order.', hotkey: '⌘K', image: placeholder, alt: 'Stash command palette' },
];
```

- [ ] **Step 2: Create `site/src/components/FeatureSection.astro`**

```astro
---
import { Image } from 'astro:assets';
import type { Feature } from '../data/features';
interface Props { feature: Feature; index: number; }
const { feature, index } = Astro.props;
const imageLeft = index % 2 === 1;
---
<section class={`feat ${imageLeft ? 'feat--rev' : ''}`} id={feature.id}>
  <div class="container feat__inner">
    <div class="feat__text" data-reveal>
      <p class="feat__eyebrow">{feature.eyebrow}</p>
      <h2 class="feat__title">{feature.title}</h2>
      <p class="feat__body">{feature.body}</p>
      {feature.hotkey && <span class="feat__key">{feature.hotkey}</span>}
    </div>
    <figure class="frame feat__media" data-reveal>
      <Image src={feature.image} alt={feature.alt} widths={[480, 800, 1100]} sizes="(max-width: 800px) 100vw, 540px" />
    </figure>
  </div>
</section>
<style>
  .feat__inner { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-16); align-items: center; padding-block: var(--space-24); }
  .feat--rev .feat__media { order: -1; }
  .feat__eyebrow { color: var(--accent-strong); font-weight: 600; text-transform: uppercase; letter-spacing: 0.06em; font-size: 0.8rem; }
  .feat__title { font-size: var(--step-3); margin-top: var(--space-3); max-width: 16ch; }
  .feat__body { color: var(--ink-soft); font-size: var(--step-1); margin-top: var(--space-4); max-width: 46ch; }
  .feat__key { display: inline-block; margin-top: var(--space-6); font-family: var(--font-display); font-weight: 600; background: var(--accent-tint); color: var(--accent-strong); padding: var(--space-2) var(--space-3); border-radius: 8px; }
  .feat__media { margin: 0; }
  @media (max-width: 800px) {
    .feat__inner { grid-template-columns: 1fr; gap: var(--space-8); padding-block: var(--space-16); }
    .feat--rev .feat__media { order: 0; }
  }
</style>
```

- [ ] **Step 3: Update `site/src/pages/index.astro`** to render the tour (add `<section id="features">` wrapper + map features).

```astro
---
import Base from '../layouts/Base.astro';
import Nav from '../components/Nav.astro';
import Hero from '../components/Hero.astro';
import FeatureSection from '../components/FeatureSection.astro';
import { features } from '../data/features';
---
<Base title="Stash — your menu-bar command center for macOS" description="Clipboard history, snippets, tasks, sticky notes and window snapping in one fast macOS menu-bar app.">
  <Nav />
  <main>
    <Hero />
    <div id="features">
      {features.map((f, i) => <FeatureSection feature={f} index={i} />)}
    </div>
  </main>
</Base>
```

- [ ] **Step 4: Build + verify all 7 pillars render with alt text**

Run: `cd site && npm run build`
Then:
```bash
for t in "instantly back" "Type less" "plain English" "stay in sight" "without the mouse" "menu bar" "⌘K"; do grep -qF "$t" site/dist/index.html || echo "MISSING: $t"; done; echo done
grep -c 'alt=' site/dist/index.html   # expect >= 8 (hero + 7)
```
Expected: no `MISSING:` lines; alt count ≥ 8.

- [ ] **Step 5: Commit**

```bash
git add site/ && git commit -m "feat(site): reusable feature sections + 7-pillar tour"
```

---

### Task 4: Works-your-way, Privacy, Download CTA, Footer

**Files:**
- Create: `site/src/components/WorksYourWay.astro`, `site/src/components/Privacy.astro`, `site/src/components/DownloadCTA.astro`, `site/src/components/Footer.astro`
- Modify: `site/src/pages/index.astro`

**Interfaces:**
- Consumes: the `DOWNLOAD_URL` convention (`https://github.com/Rohithgilla12/stash/releases/latest` until Task 7).
- Produces: four prop-less components; `DownloadCTA` renders `<section id="download">` (the nav CTA + hero anchor target).

- [ ] **Step 1: Create `site/src/components/WorksYourWay.astro`** — global hotkeys + `stash://` deeplinks copy, in a calm two-column band (NOT a card grid). Include the literal strings `stash://` and `Raycast`/`Karabiner`.

```astro
---
const items = ['⌃⌥V — Paste browser', '⌃⌥S — Sticky notes', '⌃⌥C — Quick capture', '⌘K — Command palette'];
---
<section class="band">
  <div class="container">
    <p class="feat__eyebrow">Works your way</p>
    <h2 class="band__title">Your keys, or ours.</h2>
    <p class="band__body">Global hotkeys out of the box — or skip them entirely and trigger every action with a <code>stash://</code> deeplink wired into Raycast or Karabiner.</p>
    <ul class="band__keys">{items.map((i) => <li>{i}</li>)}</ul>
  </div>
</section>
<style>
  .band { background: var(--surface); border-block: 1px solid var(--hairline); }
  .band > .container { padding-block: var(--space-24); }
  .band__title { font-size: var(--step-3); margin-top: var(--space-3); }
  .band__body { color: var(--ink-soft); font-size: var(--step-1); margin-top: var(--space-4); max-width: 60ch; }
  .band__body code { background: var(--accent-tint); color: var(--accent-strong); padding: 0.1em 0.4em; border-radius: 6px; }
  .band__keys { list-style: none; padding: 0; margin: var(--space-8) 0 0; display: flex; flex-wrap: wrap; gap: var(--space-3); }
  .band__keys li { font-family: var(--font-display); font-weight: 600; border: 1px solid var(--hairline); border-radius: 8px; padding: var(--space-2) var(--space-3); }
</style>
```

- [ ] **Step 2: Create `site/src/components/Privacy.astro`** — local-first / ignore-list / no-account trust band. Include strings `local` and `ignore-list` and `No account`.

```astro
<section class="container privacy">
  <p class="feat__eyebrow">Private by default</p>
  <h2 class="band__title">Your data stays on your Mac.</h2>
  <p class="band__body">Everything lives in a local database on-device. Add a per-app ignore-list so Stash never captures from your password manager. No account, no sign-in, no cloud required.</p>
</section>
<style>
  .privacy { padding-block: var(--space-24); }
  .privacy .band__title { font-size: var(--step-3); margin-top: var(--space-3); }
  .privacy .band__body { color: var(--ink-soft); font-size: var(--step-1); margin-top: var(--space-4); max-width: 60ch; }
</style>
```

- [ ] **Step 3: Create `site/src/components/DownloadCTA.astro`**

```astro
---
const DOWNLOAD_URL = 'https://github.com/Rohithgilla12/stash/releases/latest';
---
<section class="download" id="download">
  <div class="container download__inner">
    <h2 class="download__title">Get Stash.</h2>
    <p class="download__body">Free, notarized, and it auto-updates itself via Sparkle.</p>
    <a class="btn btn--primary" href={DOWNLOAD_URL}>Download for macOS</a>
    <p class="hero__meta">macOS 14+ · Apple Silicon &amp; Intel</p>
  </div>
</section>
<style>
  .download { background: var(--accent-tint); border-block: 1px solid var(--hairline); }
  .download__inner { text-align: center; padding-block: var(--space-24); }
  .download__title { font-size: var(--step-3); }
  .download__body { color: var(--ink-soft); font-size: var(--step-1); margin: var(--space-4) 0 var(--space-8); }
</style>
```

- [ ] **Step 4: Create `site/src/components/Footer.astro`** — GitHub, releases/changelog, made-by (personal only). NO employer name.

```astro
<footer class="footer">
  <div class="container footer__inner">
    <span class="footer__brand">Stash</span>
    <nav class="footer__links">
      <a href="https://github.com/Rohithgilla12/stash">GitHub</a>
      <a href="https://github.com/Rohithgilla12/stash/releases">Changelog</a>
      <a href="https://github.com/Rohithgilla12">Made by Rohith</a>
    </nav>
  </div>
</footer>
<style>
  .footer { border-top: 1px solid var(--hairline); }
  .footer__inner { display: flex; justify-content: space-between; align-items: center; padding-block: var(--space-8); flex-wrap: wrap; gap: var(--space-4); }
  .footer__brand { font-family: var(--font-display); font-weight: 800; }
  .footer__links { display: flex; gap: var(--space-6); }
  .footer__links a { color: var(--ink-soft); text-decoration: none; }
</style>
```

- [ ] **Step 5: Update `index.astro`** to import + place the four components after the features (`WorksYourWay`, `Privacy`, `DownloadCTA`, `Footer` — Footer outside `<main>`).

- [ ] **Step 6: Build + verify**

Run: `cd site && npm run build`
Then:
```bash
for t in "stash://" "Raycast" "ignore-list" "No account" 'id="download"' "Made by Rohith"; do grep -qF "$t" site/dist/index.html || echo "MISSING: $t"; done
grep -iq "fusang" site/dist/index.html && echo "FAIL: employer name present" || echo "clean"
echo done
```
Expected: no `MISSING:` lines; prints `clean`.

- [ ] **Step 7: Commit**

```bash
git add site/ && git commit -m "feat(site): works-your-way, privacy, download CTA, footer"
```

---

### Task 5: Scroll-reveal + nav-on-scroll (progressive enhancement)

**Files:**
- Create: `site/src/scripts/enhance.ts`
- Modify: `site/src/layouts/Base.astro` (load the script), `site/src/styles/global.css` (reveal styles)

**Interfaces:**
- Consumes: the `data-reveal` attribute (Tasks 2–4) and `#site-nav`.
- Produces: reveal-on-scroll + `is-scrolled` nav toggle, both no-ops under `prefers-reduced-motion`.

- [ ] **Step 1: Add reveal styles to `global.css`**

```css
[data-reveal] { opacity: 0; transform: translateY(12px); transition: opacity 0.5s ease-out, transform 0.5s ease-out; }
[data-reveal].is-in { opacity: 1; transform: none; }
@media (prefers-reduced-motion: reduce) { [data-reveal] { opacity: 1; transform: none; transition: none; } }
```

- [ ] **Step 2: Create `site/src/scripts/enhance.ts`**

```ts
const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const nav = document.getElementById('site-nav');
const onScroll = () => nav?.classList.toggle('is-scrolled', window.scrollY > 8);
onScroll();
window.addEventListener('scroll', onScroll, { passive: true });

const reveals = document.querySelectorAll<HTMLElement>('[data-reveal]');
if (reduce || !('IntersectionObserver' in window)) {
  reveals.forEach((el) => el.classList.add('is-in'));
} else {
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); }
  }, { rootMargin: '0px 0px -10% 0px' });
  reveals.forEach((el) => io.observe(el));
}
```

- [ ] **Step 3: Load the script in `Base.astro`** — before `</body>`: `<script src="../scripts/enhance.ts"></script>` (Astro bundles + defers it).

- [ ] **Step 4: Build + verify the script bundles**

Run: `cd site && npm run build`
Then: `grep -rqE "is-scrolled|IntersectionObserver" site/dist/ && echo OK`
Expected: `OK` (the bundled JS is emitted). Manually: `npm run dev`, scroll → sections fade/rise in and the nav gains a backdrop; toggle Reduce Motion → content shows immediately.

- [ ] **Step 5: Commit**

```bash
git add site/ && git commit -m "feat(site): scroll-reveal + nav-on-scroll (reduced-motion safe)"
```

---

### Task 6: Real screenshots (controller-assisted capture + framing)

> **Note for the implementer:** capturing live macOS app screenshots requires the running Stash app and a GUI session — this is done in the **main session** (the controller), not inside a headless subagent. The controller will place optimized PNGs in `site/src/assets/screens/`. This task wires them in and is verified once the files exist. If the files are absent, leave the placeholder and report `BLOCKED: awaiting screenshots`.

**Files:**
- Create: `site/src/assets/screens/{hero,clipboard,snippets,tasks,stickies,windows,focus,ai}.png` (controller-provided)
- Modify: `site/src/data/features.ts`, `site/src/components/Hero.astro`

**Capture checklist (controller):** light-mode, retina, the dev or prod app, each pillar's primary surface (hub popover for hero, paste browser for clipboard with ⌘N badges, snippet editor + fill-in form, tasks list with a NL/recurring/reminder item, desktop stickies, a snap, the focus timer, the ⌘K palette). Trim to the window; keep widths ≤ 1600px. One dark shot (clipboard) is optional.

- [ ] **Step 1: Confirm assets exist**

Run: `ls site/src/assets/screens/*.png | wc -l`
Expected: ≥ 8. If 0 → `BLOCKED: awaiting screenshots`.

- [ ] **Step 2: Swap imports in `features.ts`** — replace `placeholder` per feature with the matching screen import, e.g. `import clipboard from '../assets/screens/clipboard.png';` and set `image: clipboard`. Keep the same `alt` text.

- [ ] **Step 3: Swap the hero image** in `Hero.astro` to `../assets/screens/hero.png` with descriptive alt.

- [ ] **Step 4: Build + verify real images are emitted (no placeholder left)**

Run: `cd site && npm run build`
Then: `grep -c "placeholder" site/dist/index.html` (expect `0`) and `ls site/dist/assets | grep -ciE "clipboard|hero"` (expect ≥ 2).
Expected: no placeholder references; optimized screenshots emitted.

- [ ] **Step 5: Commit**

```bash
git add site/ && git commit -m "feat(site): real product screenshots across the tour"
```

---

### Task 7: Download link finalisation

**Files:**
- Modify: `site/src/components/Hero.astro`, `site/src/components/DownloadCTA.astro`
- Modify (conditional): `.github/workflows/release.yml`

**Interfaces:** Produces the final `DOWNLOAD_URL` used by both CTAs.

> **Decision (ask the user):** **(A)** direct download via a stable asset — add a step to `release.yml` to also upload the DMG as `Stash.dmg`, then point both CTAs at `https://github.com/Rohithgilla12/stash/releases/latest/download/Stash.dmg`. **(B)** zero-pipeline — leave both CTAs pointing at `https://github.com/Rohithgilla12/stash/releases/latest`. Default to (A) if the user has no preference.

- [ ] **Step 1 (if A): Add the stable-asset step to `release.yml`** — after the DMG is built/named, before notarize: `cp "$DMG" Stash.dmg` and include `Stash.dmg` in the release upload assets list. (Find the existing `gh release create`/upload step and add `Stash.dmg` to it.)

- [ ] **Step 2: Set `DOWNLOAD_URL`** in both `Hero.astro` and `DownloadCTA.astro` to the chosen URL (identical in both — DRY note: acceptable duplication of one constant; do not over-abstract).

- [ ] **Step 3: Build + verify the link**

Run: `cd site && npm run build`
Then: `grep -oE 'https://github.com/Rohithgilla12/stash/releases[^"]*' site/dist/index.html | sort -u`
Expected: shows the chosen URL (same in hero + CTA). If (A), confirm the URL ends in `/Stash.dmg`.

- [ ] **Step 4: Commit**

```bash
git add site/ .github/workflows/release.yml 2>/dev/null; git commit -m "feat(site): finalise download link"
```

---

### Task 8: Polish — meta, OG image, favicon, responsive + a11y pass

**Files:**
- Create: `site/public/favicon.svg`, `site/public/og.png` (controller-provided or generated), `site/public/robots.txt`
- Modify: `site/src/layouts/Base.astro` (favicon + OG image meta), `site/src/styles/global.css` (any responsive fixes found)

**Interfaces:** none new.

- [ ] **Step 1: Add favicon + OG + robots** — `favicon.svg` (a simple terracotta mark), `og.png` (1200×630 social card; controller may reuse the hero), `robots.txt` (`User-agent: *\nAllow: /`). Reference favicon + `og:image` (absolute via `Astro.site`) in `Base.astro`.

- [ ] **Step 2: Responsive + a11y sweep** — run `npm run dev`, check 375px / 768px / 1280px widths: hero, every `FeatureSection` (stacks single-column, image never overflows), nav (links collapse to just Download on mobile), download band. Verify focus rings on all links/buttons, alt text present, and AA contrast on terracotta-on-warm (`#c8642f` on `--canvas`; darken to `--accent-strong` for text if a check fails). Fix issues in `global.css`/components.

- [ ] **Step 3: Build + verify meta + no horizontal scroll**

Run: `cd site && npm run build`
Then:
```bash
grep -q 'rel="icon"' site/dist/index.html && grep -q 'og:image' site/dist/index.html && echo "meta OK"
grep -iq "fusang" site/dist/index.html && echo "FAIL employer" || echo "name clean"
```
Expected: `meta OK` and `name clean`. Manually confirm no horizontal scrollbar at 375px.

- [ ] **Step 4: Publish an Artifact preview** (controller) — render the built page so the user can review before pointing a domain at it.

- [ ] **Step 5: Commit**

```bash
git add site/ && git commit -m "feat(site): favicon, OG card, responsive + a11y polish"
```

---

## Final verification (after all tasks)

- `cd site && rm -rf dist && npm run build` → clean build.
- The 7 pillar titles, `stash://`, `ignore-list`, the download URL, favicon + OG meta all present in `dist/index.html`; no `placeholder`, no `fusang`.
- Manual: dev server reviewed at mobile + desktop; reduced-motion honored.
- Artifact preview shared with the user.
- The user connects `/site` to Cloudflare Pages (root `/site`, build `npm run build`, output `dist`) — **outside this repo's code**.
