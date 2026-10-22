# hufu.yufan.dev

Hufu（虎符输入法）官网：自定义设计的 Astro 静态站点，散文正文用 MDX 生成，构建产物
发布到 `gh-pages` 分支，由 GitHub Pages 提供 `https://hufu.yufan.dev`（域名由
`public/CNAME` 固定）。

## 开发

```bash
npm ci            # 安装依赖（astro 与 @astrojs/mdx 都钉死版本）
npm run dev       # 本地预览，默认 http://localhost:4321
npm run build     # 构建到 dist/
bash ../scripts/check-site.sh dist   # 起本地 http.server，校验全部内部引用
```

需要 Node.js 22.23.4 或更新版本（CI 用 Node 24）。

## 结构

```
site/
  astro.config.mjs      site、clean URL、MDX 集成（关闭 smartypants，避免正文变排印符号）
  public/               原样拷贝进 dist/：CNAME、icon.png、og.png、brand/、avatars/、
                        screenshots/、themes/renders/、assets/（CSS 与 island 脚本）
  src/lib/site.ts       locale 元数据、页头页脚与弹窗文案、搜索索引、JSON-LD 软件节点
  src/layouts/Base.astro  <head>（meta / OG / hreflang / JSON-LD）、页头页脚、搜索与菜单弹窗
  src/content.config.ts pages collection（glob + zod：title、description、application）
  src/content/pages/    18 篇 MDX 正文：<locale>/<route>.mdx（id 形如 zh/download）
  src/pages/            [...slug].astro 生成 18 条散文路由；首页与主题页仍是静态 .astro
```

散文类路由（download、dictionaries、docs、changelog、privacy、open-source）由
`src/pages/[...slug].astro` 一条动态路由生成：`getStaticPaths()` 读取 `pages`
collection，按 id 的第一段决定语言前缀（`zh` 无前缀，`zh-hant` / `en` 加对应前缀），
再用 `render(entry)` 取 `<Content />` 套进 `Base`。它只生成这 18 条路径，不碰首页与
`themes`，静态路由优先也不冲突。

**加一篇散文页**：在 `src/content/pages/zh/`、`zh-hant/`、`en/` 各放一篇同名 `.mdx`
（如 `download.mdx`），frontmatter 写 `title`、`description`（可选 `application: true`
给下载页加 SoftwareApplication JSON-LD），无需改路由。正文整页包在一个 `<main>` 里，
按 JSX 规则书写：`class` → `className`，`img`/`input`/`br` 自闭合；`for`、`srcset`、
SVG 的 `stroke-width` 等保留 HTML 原名（Astro 不会把驼峰属性映射回 HTML）。CJK 段落
保持单行（软换行会变成空格）。代码块正文用 `{`…`}` 字符串表达式包住，否则 MDX 会把
`--` 变排印符号、把 URL 自动变成链接（构建时用 `smartypants: false` 关掉前者，表达式
同时挡住自动链接）。改完用 `git worktree` 拉出基线按文本 / 图片 / 链接逐页比对。

首页（`index.astro`）与主题页（`themes/index.astro`）是重设计页面，保留 `.astro` 而不套
MDX。导航、页脚、搜索条目和语言文案集中在 `src/lib/site.ts` 的 `chrome`，改一处三语言
同时生效。

`public/assets/` 里的 CSS 与脚本是原样保留的静态资源（`layout.js` 管导航/搜索/主题切换/
词库筛选，`home.js` + `home-sections.js` 管首页主题切换与常用语演示，`themes.js` 管主题
画廊与 YAML 生成，`theme-geometry.js` 被后两者 import）。它们不走 Astro 打包，URL 稳定；
页面里用 `<script type="module" src="/assets/…" is:inline>` 引入。

## 主题载荷

`themes/index.astro` 的 `data-d` 与安装链接里内嵌 `hufu-ime://theme?v=2&d=…` 的
base64url 载荷，共 8 套、三语言各一份。载荷必须与 `SharedSupport/hufu.yaml` 的
`preset_color_schemes` 对齐，并满足 App `ThemePackage` 的约束：`format: hufu-theme`、
`version: 2`、13 个颜色键（yaml 省略的 `preedit_back_color` 按 RIME 默认补
`0X00000000`）、9 个布局键、键名排序。**改配色时同时更新 yaml 与三份 themes 页面里的
载荷**，否则站点发出的主题会被 App 拒收。

## 图片

`themes/renders/` 是候选窗主题渲染图（由仓库内 `ThemeRenderProbe` 生成），
`screenshots/` 是设置页截图（`scripts/ui-shots.sh` 生成），`brand/` 是品牌 SVG，
`avatars/` 是首页演示用的头像。

## 来源与禁止事项

页面骨架与 CSS/JS 最初参考 AIME 文档站（aime.zool.app）的渲染产物适配；AIME 是 ZOOL 的
开源项目（zoolapp/aime，© 2026 ZOOL LLC，MIT），Hufu 由其派生，保留原许可与署名。
界面文案、链接与图片均已按 Hufu 重写。**不要向本目录加入任何带 AIME 字样的图片或品牌资源。**
唯一保留的 AIME 出处说明是 `open-source` 页的致谢行。

## 部署

`.github/workflows/site.yml`：push 到 `main` 且改动 `site/**` 时，用 Node 24 + npm 缓存
执行 `npm ci` → `npm run build` → `scripts/check-site.sh site/dist`，然后把 `site/dist`
以纯 git 方式发布到 `gh-pages`（内容未变则跳过提交）。
