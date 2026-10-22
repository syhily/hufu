# hufu.yufan.dev

Hufu（虎符输入法）官网，由 GitHub Pages 服务（`CNAME` = `hufu.yufan.dev`）。

本目录是**源目录**：推送到 main 后，`.github/workflows/site.yml` 先跑
`scripts/check-site.sh`，再把本目录内容发布到 `gh-pages` 分支（每改动一个提交，
无变化则跳过）；GitHub Pages 以 `gh-pages` 分支为源对外服务。不要手工改 `gh-pages`
分支。

## 来源

页面骨架与 CSS/JS 来自 AIME（艾么输入法，作者自己的旧项目）文档站的 Astro 渲染产物，
已获授权适配：HTML 结构与 class 保持原样（主题预览等 Astro island 依赖它们），只替换了
文案、链接、图片与品牌资源。主题渲染图由本仓库的 `ThemeRenderProbe` 生成，设置截图由
`scripts/ui-shots.sh` 从本机构建的 Hufu Settings 截取。

**不要向本目录加入任何带 AIME 字样的图片或品牌资源。** 唯一保留的 AIME 出处说明是
`open-source/` 页的致谢行（历史来源说明）。

## 编辑

站点是纯静态文件，改完直接提交到 main 即可，发布由 Action 完成（见上）。

- `index.html`、`zh-hant/index.html`、`en/index.html`：首页
- `<page>/index.html`（`zh-hant/`、`en/` 下同名）：download / dictionaries / themes /
  docs / changelog / privacy / open-source
- `_astro/`：样式与 Astro island 脚本；`brand/`、`avatars/`、`icon.png`、`og.png`：图片
- `themes/renders/*.png`：候选窗主题渲染图（`ThemeRenderProbe` 生成）
- `screenshots/settings/*.png`：设置页截图（`scripts/ui-shots.sh` 生成）

本地预览：`python3 -m http.server -d site 8000`，然后打开 http://localhost:8000/ 。
链接检查：`bash scripts/check-site.sh`。
