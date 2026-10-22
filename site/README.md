# hufu.yufan.dev

Hufu（虎符输入法）官网：Astro + Starlight + MDX 的静态站点，构建产物发布到 `gh-pages`
分支，由 GitHub Pages 提供 `https://hufu.yufan.dev`（域名由 `public/CNAME` 固定）。

## 开发

```bash
npm ci                              # 安装依赖（版本在 package.json 里精确钉住）
npm run dev                         # 本地预览，默认 http://localhost:4321
npm run build                       # 构建到 dist/
bash ../scripts/check-site.sh dist  # 起本地 http.server，校验全部内部引用与锚点
```

需要 Node.js 22 或更新版本。

## 结构

```
site/
  astro.config.mjs       site、clean URL、Starlight 配置（侧栏、语言、head、JSON-LD）
  src/content.config.ts  docs 与 i18n 两个 collection（Starlight loader + schema）
  src/content/docs/      中文（root）8 个页面
  src/content/docs/zh-hant/  繁体 8 个页面
  src/content/docs/en/       英文 8 个页面
  src/content/i18n/      Starlight 界面文案（zh-Hans / zh-Hant，覆盖搜索、目录、404 等）
  src/components/ThemeGallery.astro  主题画廊（卡片、安装链接、复制 YAML）
  src/lib/themes.ts      8 套主题的配色与布局数据，生成 hufu-ime://theme 载荷
  src/styles/hufu.css    品牌色、明暗两套变量、图片明暗切换、主题卡样式
  src/assets/            Starlight 顶栏 logo（mark-vermilion.svg / mark-white.svg）
  public/                原样拷贝进 dist/：CNAME、icon.png、og.png、brand/、avatars/、
                         screenshots/、themes/renders/
```

## 加页面

1. 在 `src/content/docs/<slug>.mdx` 写简体页，`title` 与 `description` 用 frontmatter。
2. 同 slug 写到 `src/content/docs/zh-hant/<slug>.mdx` 与 `en/<slug>.mdx`。Starlight 会给
   `zh-hant/`、`en/` 自动加语言前缀，路由分别是 `/zh-hant/<slug>/`、`/en/<slug>/`。
   缺译时 Starlight 会用中文正文回退渲染并在页头提示，直到补齐。
3. 在 `astro.config.mjs` 的 `sidebar` 加一项：`slug` 只写不带语言前缀的 slug，
   标签放在 `label`，繁体与英文放在 `translations`（键是 `zh-Hant`、`en`）。

首页用 `template: splash` + `hero`，正文里用 `@astrojs/starlight/components` 的
`Card` / `CardGrid` 排版；其余页面走默认文档模板。

Starlight 内置界面文案只带 `zh`、`zh-TW` 等代码；本站语言标签是 `zh-Hans` /
`zh-Hant`，所以 `src/content/i18n/` 里放了两份完整字典（源自 Starlight 的
`zh-CN` / `zh-TW`），否则搜索、目录、404 等界面会漏出原始键名。

## 主题画廊

`src/lib/themes.ts` 是 `SharedSupport/hufu.yaml` 里 `preset_color_schemes` 与
`style/hufu` 的手工镜像：每套主题的 13 个颜色键与 9 个布局键必须与 yaml 一致
（yaml 省略的 `preedit_back_color` 按面板默认补成透明）。
`payload()` 生成 `hufu-theme` v2 的规范 JSON（键排序，base64url），`installLink()`
拼成 `hufu-ime://theme?v=2&d=…`，`yamlSnippet()` 生成可粘贴的 YAML。

**改配色方案时同步改两处**：`SharedSupport/hufu.yaml`（App 实际使用）与
`src/lib/themes.ts`（站点展示与安装链接），否则站点发出的主题与 App 内置的不一致。
渲染图在 `public/themes/renders/`，由仓库内的 `ThemeRenderProbe` 生成。

## 图片

`public/screenshots/` 是设置页截图（`scripts/ui-shots.sh` 生成，含 `settings/` 明细与
首页 hero 的 640/960/1440 三档），`public/brand/` 是品牌 SVG，`public/avatars/` 是
演示用头像。页面里的明暗切换用 `only-light` / `only-dark` 两个 class（见 `hufu.css`）。

## 来源与禁止事项

页面结构参考了 AIME（艾么输入法，作者自己的旧项目）文档站，已获授权适配；界面文案、
链接与图片均已按 Hufu 重写。**不要向本目录加入任何带 AIME 字样的图片或品牌资源。**
唯一保留的 AIME 出处说明是 `open-source` 页的致谢行。

## 部署

`.github/workflows/site.yml`：push 到 `main` 且改动 `site/**` 时，用 Node 22 + npm 缓存
执行 `npm ci` → `npm run build` → `scripts/check-site.sh site/dist`，然后把 `site/dist`
以纯 git 方式发布到 `gh-pages`（内容未变则跳过提交）。
