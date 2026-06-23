# Product screenshots

The landing page currently renders `../placeholder.svg` for the hero + every
feature. To ship the real site, drop **8 PNGs** in this folder with these exact
names, then swap the imports (below). Until then the build stays green with
placeholders.

| File | Surface to capture | How to open |
|---|---|---|
| `hero.png` | The hub popover (or the paste browser — your best single shot) | click the menu-bar icon / ⌃⌥V |
| `clipboard.png` | Paste browser (cards, ⌘1–9 badges, a link preview) | ⌃⌥V |
| `snippets.png` | Snippets tab — a snippet with a `{placeholder}` / the fill-in form | hub → Snippets |
| `tasks.png` | Tasks — a list with an NL/recurring/reminder item | hub → To-dos |
| `stickies.png` | A desktop sticky note (or two) | ⌃⌥S |
| `windows.png` | A window snapped via the snap shortcuts | hub → Windows |
| `focus.png` | The focus/Pomodoro timer | hub → Focus |
| `ai.png` | The ⌘K command palette (or the AI tab) | ⌘K |

## Capture tips (marketing quality)
- **Light mode**, retina (2×), a **clean desktop** (hide other windows / use a plain wallpaper — the paste browser is translucent and shows whatever is behind it).
- Real, friendly **content** — not test strings. Trim to the window; keep width ≤ ~1600px.
- One **dark-mode** shot (e.g. `clipboard.png`) is a nice contrast if you like.

## Wiring the real images (after the PNGs are here)
1. In `site/src/data/features.ts`, replace the shared `placeholder` import per
   feature, e.g. `import clipboard from '../assets/screens/clipboard.png';` and
   set that feature's `image: clipboard` (repeat for snippets/tasks/stickies/
   windows/focus/ai).
2. In `site/src/components/Hero.astro`, import `../assets/screens/hero.png` and
   use it as the hero `<Image src>`.
3. `cd site && npm run build` — confirm `grep -c placeholder dist/index.html` is `0`.

(Or hand the 8 files to Claude and it will do the swap + rebuild.)

## Before go-live (Cloudflare)
- Set the real domain in `site/astro.config.mjs` (`site: 'https://your-domain'`) and
  rebuild — the OG/Twitter card URL is absolute and currently points at the
  `stash.example` placeholder, so social previews 404 until this is set.
- In Cloudflare Pages: root directory `site`, build `npm run build`, output `dist`.
