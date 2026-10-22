# hufu.yufan.dev

Hufu（虎符输入法）官网，Astro 静态站点，构建产物发布到 `gh-pages` 分支，由 GitHub Pages
提供 `https://hufu.yufan.dev`（域名由 `public/CNAME` 固定）。

## 开发

```bash
npm ci            # 安装依赖（只依赖 astro，版本在 package.json 里钉住）
npm run dev       # 本地预览，默认 http://localhost:4321
npm run build     # 构建到 dist/
bash ../scripts/check-site.sh dist   # 起本地 http.server，校验全部内部引用
```

需要 Node.js 22 或更新版本。

## 结构

```
site/
  astro.config.mjs      site、clean URL（每页构建成 <route>/index.html）
  public/               原样拷贝进 dist/：CNAME、icon.png、og.png、brand/、avatars/、
                        screenshots/、themes/renders/、assets/（CSS 与 island 脚本）
  src/lib/site.ts       locale 元数据、页头页脚与弹窗文案、搜索索引、JSON-LD 软件节点
  src/layouts/Base.astro  <head>（meta / OG / hreflang / JSON-LD）、页头页脚、搜索与菜单弹窗
  src/pages/            24 个路由：index、download、dictionaries、themes、docs、
                        changelog、privacy、open-source，各含 zh-Hans / zh-hant / en
```

页面文案写在各自的 `.astro` 里（`<main>` 直接是 HTML，class 与 id 是 island 脚本的接口，
改动前先看 `public/assets/*.js`）；`<head>`、导航、页脚、语言切换都在 `Base.astro`，改一处
三语言同时生效——语言差异集中在 `src/lib/site.ts` 的 `chrome`。

`public/assets/` 里的 CSS 与脚本是原样保留的静态资源（`layout.js` 管导航/搜索/主题切换，
`home.js` + `home-sections.js` 管首页主题切换与常用语演示，`themes.js` 管主题画廊，
`theme-geometry.js` 被后两者 import）。它们不走 Astro 打包，URL 稳定；页面里用
`<script type="module" src="/assets/…" is:inline>` 引入。

图片：`themes/renders/` 是候选窗主题渲染图（由仓库内 `ThemeRenderProbe` 生成），
`screenshots/` 是设置页截图（`scripts/ui-shots.sh` 生成），`brand/` 是品牌 SVG，
`avatars/` 是首页演示用的头像。

## 来源与禁止事项

页面骨架与 CSS/JS 最初来自 AIME（艾么输入法，作者自己的旧项目）文档站，已获授权适配；
界面文案、链接与图片均已按 Hufu 重写。**不要向本目录加入任何带 AIME 字样的图片或品牌资源。**
唯一保留的 AIME 出处说明是 `open-source` 页的致谢行。

## 部署

`.github/workflows/site.yml`：push 到 `main` 且改动 `site/**` 时，用 Node 22 + npm 缓存
执行 `npm ci` → `npm run build` → `scripts/check-site.sh site/dist`，然后把 `site/dist`
以纯 git 方式发布到 `gh-pages`（内容未变则跳过提交）。
