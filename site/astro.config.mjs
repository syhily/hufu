// @ts-check
import { defineConfig } from 'astro/config';

// GitHub Pages, clean URLs: every page builds to <route>/index.html.
export default defineConfig({
  site: 'https://hufu.yufan.dev',
  output: 'static',
  trailingSlash: 'always',
  build: { format: 'directory' },
});
