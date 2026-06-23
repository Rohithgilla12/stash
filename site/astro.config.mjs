import { defineConfig } from 'astro/config';

// `site` is a placeholder — the user sets the real domain in Cloudflare.
// Static output only; no deploy adapter (deploy is Cloudflare's job).
export default defineConfig({
  site: 'https://stash.example',
  output: 'static',
  build: { assets: 'assets' },
});
