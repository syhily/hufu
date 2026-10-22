/**
 * Site-wide constants: locale metadata, the chrome strings, the search index and the
 * JSON-LD software node. Page copy lives with each page under src/pages.
 */
export const site = 'https://hufu.yufan.dev';

export type Locale = 'zh' | 'zh-hant' | 'en';

export const langOf: Record<Locale, string> = { zh: 'zh-Hans', 'zh-hant': 'zh-Hant', en: 'en' };
export const ogLocaleOf: Record<Locale, string> = { zh: 'zh_CN', 'zh-hant': 'zh_TW', en: 'en_US' };

/** '' for the zh-Hans home page, '/zh-hant/', '/en/download/' … */
export function pagePath(locale: Locale, slug: string): string {
  const prefix = locale === 'zh' ? '' : `/${locale}`;
  return slug ? `${prefix}/${slug}/` : `${prefix}/`;
}

export interface NavItem { slug: string; label: string }
export interface LanguageItem { locale: Locale; short: string; name: string }

export interface Chrome {
  siteAlternateName: string[];
  skip: string;
  brandHome: string;
  mainNav: string;
  nav: NavItem[];
  githubAria: string;
  githubTitle: string;
  githubBadge: string;
  starsAria: string;
  searchAria: string;
  searchTitle: string;
  themeToggle: string;
  themeDark: string;
  themeLight: string;
  chooseLanguage: string;
  shortLabel: string;
  language: string;
  languages: LanguageItem[];
  openMenu: string;
  tagline: string;
  footerNav: string;
  footer: NavItem[];
  copyright: string;
  footerRepo: string;
  searchHeading: string;
  closeSearch: string;
  searchLabel: string;
  searchPlaceholder: string;
  searchEmpty: string;
  searchHint: string;
  menuHeading: string;
  closeMenu: string;
  menuGithub: string;
  menu: NavItem[];
  ogImageAlt: string;
  hint?: { locale: Locale; label: string; close: string };
}

const LANGUAGES: LanguageItem[] = [
  { locale: 'zh', short: '简', name: '简体中文' },
  { locale: 'zh-hant', short: '繁', name: '繁體中文' },
  { locale: 'en', short: 'EN', name: 'English' },
];

export const chrome: Record<Locale, Chrome> = {
  zh: {
    siteAlternateName: ['虎符输入法'],
    skip: '跳至主要内容',
    brandHome: 'Hufu 首页',
    mainNav: '主导航',
    nav: [
      { slug: 'download', label: '安装与下载' },
      { slug: 'dictionaries', label: '词库资源' },
      { slug: 'themes', label: '主题' },
      { slug: 'docs', label: '使用文档' },
      { slug: 'open-source', label: '开源与致谢' },
    ],
    githubAria: 'GitHub · Hufu 开源仓库（在新窗口打开）',
    githubTitle: '在 GitHub 查看 Hufu 源码',
    githubBadge: '开源',
    starsAria: 'GitHub Star 数',
    searchAria: '搜索页面与文档',
    searchTitle: '搜索 · ⌘K',
    themeToggle: '切换主题',
    themeDark: '切换深色主题',
    themeLight: '切换浅色主题',
    chooseLanguage: '选择语言',
    shortLabel: '简',
    language: '语言',
    languages: LANGUAGES,
    openMenu: '打开菜单',
    tagline: '中文常新，自在表达。',
    footerNav: '页脚导航',
    footer: [
      { slug: 'docs', label: '使用文档' },
      { slug: 'changelog', label: '更新记录' },
      { slug: 'privacy', label: '隐私说明' },
      { slug: 'open-source', label: '开源与致谢' },
    ],
    copyright: '© 2026 syhily · Hufu · 基于 RIME',
    footerRepo: 'GitHub 仓库',
    searchHeading: '搜索 Hufu',
    closeSearch: '关闭搜索',
    searchLabel: '搜索页面与文档',
    searchPlaceholder: '搜索安装、词汇、常用语、隐私…',
    searchEmpty: '没有找到相关内容，试试「词库」「主题」或「安装」。',
    searchHint: 'Tab 选择 · Enter 打开 · Esc 关闭',
    menuHeading: '探索 Hufu',
    closeMenu: '关闭菜单',
    menuGithub: 'GitHub · 开源代码',
    menu: [
      { slug: 'download', label: '安装与下载' },
      { slug: 'dictionaries', label: '词库资源' },
      { slug: 'themes', label: '主题' },
      { slug: 'docs', label: '使用文档' },
      { slug: 'changelog', label: '更新记录' },
      { slug: 'privacy', label: '隐私说明' },
      { slug: 'open-source', label: '开源与致谢' },
    ],
    ogImageAlt: 'Hufu 虎符输入法，基于 RIME 的开源 macOS 中文输入法',
    hint: { locale: 'zh-hant', label: '切換到繁體中文？', close: '關閉語言提示' },
  },
  'zh-hant': {
    siteAlternateName: ['虎符輸入法'],
    skip: '跳至主要內容',
    brandHome: 'Hufu 首頁',
    mainNav: '主導航',
    nav: [
      { slug: 'download', label: '安裝與下載' },
      { slug: 'dictionaries', label: '詞庫資源' },
      { slug: 'themes', label: '主題' },
      { slug: 'docs', label: '使用文件' },
      { slug: 'open-source', label: '開源與致謝' },
    ],
    githubAria: 'GitHub · Hufu 開源倉庫（在新視窗開啟）',
    githubTitle: '在 GitHub 檢視 Hufu 原始碼',
    githubBadge: '開源',
    starsAria: 'GitHub Star 數',
    searchAria: '搜尋頁面與文件',
    searchTitle: '搜尋 · ⌘K',
    themeToggle: '切換主題',
    themeDark: '切換深色主題',
    themeLight: '切換淺色主題',
    chooseLanguage: '選擇語言',
    shortLabel: '繁',
    language: '語言',
    languages: LANGUAGES,
    openMenu: '開啟選單',
    tagline: '中文常新，自在表達。',
    footerNav: '頁尾導航',
    footer: [
      { slug: 'docs', label: '使用文件' },
      { slug: 'changelog', label: '更新記錄' },
      { slug: 'privacy', label: '隱私說明' },
      { slug: 'open-source', label: '開源與致謝' },
    ],
    copyright: '© 2026 syhily · Hufu · 基於 RIME',
    footerRepo: 'GitHub 儲存庫',
    searchHeading: '搜尋 Hufu',
    closeSearch: '關閉搜尋',
    searchLabel: '搜尋頁面與文件',
    searchPlaceholder: '搜尋安裝、詞彙、常用語、隱私…',
    searchEmpty: '沒有找到相關內容，試試「詞庫」「主題」或「安裝」。',
    searchHint: 'Tab 選擇 · Enter 開啟 · Esc 關閉',
    menuHeading: '探索 Hufu',
    closeMenu: '關閉選單',
    menuGithub: 'GitHub · 開原始碼',
    menu: [
      { slug: 'download', label: '安裝與下載' },
      { slug: 'dictionaries', label: '詞庫資源' },
      { slug: 'themes', label: '主題' },
      { slug: 'docs', label: '使用文件' },
      { slug: 'changelog', label: '更新記錄' },
      { slug: 'privacy', label: '隱私說明' },
      { slug: 'open-source', label: '開源與致謝' },
    ],
    ogImageAlt: 'Hufu 虎符輸入法，基於 RIME 的開源 macOS 中文輸入法',
  },
  en: {
    siteAlternateName: ['虎符输入法'],
    skip: 'Skip to content',
    brandHome: 'Hufu home',
    mainNav: 'Main navigation',
    nav: [
      { slug: 'download', label: 'Install & download' },
      { slug: 'dictionaries', label: 'Vocabulary' },
      { slug: 'themes', label: 'Themes' },
      { slug: 'docs', label: 'Documentation' },
      { slug: 'open-source', label: 'Open source' },
    ],
    githubAria: 'GitHub · Hufu open-source repository (opens in a new tab)',
    githubTitle: 'View Hufu source on GitHub',
    githubBadge: 'Open source',
    starsAria: 'GitHub stars',
    searchAria: 'Search pages and documentation',
    searchTitle: 'Search · ⌘K',
    themeToggle: 'Toggle theme',
    themeDark: 'Switch to dark theme',
    themeLight: 'Switch to light theme',
    chooseLanguage: 'Choose language',
    shortLabel: 'EN',
    language: 'Language',
    languages: LANGUAGES,
    openMenu: 'Open menu',
    tagline: 'New words, freely yours.',
    footerNav: 'Footer navigation',
    footer: [
      { slug: 'docs', label: 'Documentation' },
      { slug: 'changelog', label: 'Changelog' },
      { slug: 'privacy', label: 'Privacy' },
      { slug: 'open-source', label: 'Open source' },
    ],
    copyright: '© 2026 syhily · Hufu · Built on RIME',
    footerRepo: 'GitHub repository',
    searchHeading: 'Search Hufu',
    closeSearch: 'Close search',
    searchLabel: 'Search pages and documentation',
    searchPlaceholder: 'Installation, snippets, privacy…',
    searchEmpty: 'Nothing found. Try “vocabulary”, “snippets” or “install”.',
    searchHint: 'Tab to choose · Enter to open · Esc to close',
    menuHeading: 'Explore Hufu',
    closeMenu: 'Close menu',
    menuGithub: 'GitHub · Open-source code',
    menu: [
      { slug: 'download', label: 'Install & download' },
      { slug: 'dictionaries', label: 'Vocabulary' },
      { slug: 'themes', label: 'Themes' },
      { slug: 'docs', label: 'Documentation' },
      { slug: 'changelog', label: 'Changelog' },
      { slug: 'privacy', label: 'Privacy' },
      { slug: 'open-source', label: 'Open source' },
    ],
    ogImageAlt: 'Hufu, an open-source macOS input method built on RIME',
  },
};

export interface SearchItem { title: string; text: string; href: string; keys: string }
export interface UiCopy { results: string; lists: string; copied: string; clipboard: string }

export const searchItems: Record<Locale, SearchItem[]> = {
  "zh": [
    {
      "title": "首页",
      "text": "只做虎码的 macOS 输入法。开源，注重隐私，基于 librime。",
      "href": "/",
      "keys": "首页 首頁 Home"
    },
    {
      "title": "安装与下载",
      "text": "0.1.0 预览版可下载，支持 macOS 15.0+，ad-hoc 签名。",
      "href": "/download/",
      "keys": "安装与下载 安裝與下載 Install download"
    },
    {
      "title": "词库",
      "text": "虎码官方秃版词库、词汇输入与三张词表、自定义短语。",
      "href": "/dictionaries/",
      "keys": "词库 詞庫 Vocabulary"
    },
    {
      "title": "主题",
      "text": "8 套配色，App 实际渲染，hufu-ime:// 一键导入。",
      "href": "/themes/",
      "keys": "主题 主題 Themes"
    },
    {
      "title": "使用文档",
      "text": "添加输入法、用界面管理配置、词汇输入、迁移、AI 与卸载。",
      "href": "/docs/",
      "keys": "使用文档 使用文件 Documentation"
    },
    {
      "title": "更新记录",
      "text": "版本改动与发布说明。",
      "href": "/changelog/",
      "keys": "更新记录 更新記錄 Changelog"
    },
    {
      "title": "隐私说明",
      "text": "日常输入在本机处理；没有在线订阅，也没有统计 SDK。",
      "href": "/privacy/",
      "keys": "隐私说明 隱私說明 Privacy"
    },
    {
      "title": "开源与致谢",
      "text": "Hufu 原创代码 MIT，第三方组件保留各自许可。",
      "href": "/open-source/",
      "keys": "开源与致谢 開源與致謝 Open source"
    }
  ],
  "zh-hant": [
    {
      "title": "首頁",
      "text": "只做虎碼的 macOS 輸入法。開源，注重隱私，基於 librime。",
      "href": "/zh-hant/",
      "keys": "首頁 首页 Home"
    },
    {
      "title": "安裝與下載",
      "text": "0.1.0 預覽版可下載，支援 macOS 15.0+，ad-hoc 簽名。",
      "href": "/zh-hant/download/",
      "keys": "安裝與下載 安装与下载 Install download"
    },
    {
      "title": "詞庫",
      "text": "虎碼官方禿版詞庫、詞彙輸入與三張詞表、自訂短語。",
      "href": "/zh-hant/dictionaries/",
      "keys": "詞庫 词库 Vocabulary"
    },
    {
      "title": "主題",
      "text": "8 套配色，App 實際渲染，hufu-ime:// 一鍵匯入。",
      "href": "/zh-hant/themes/",
      "keys": "主題 主题 Themes"
    },
    {
      "title": "使用文件",
      "text": "新增輸入法、用介面管理設定、詞彙輸入、遷移、AI 與解除安裝。",
      "href": "/zh-hant/docs/",
      "keys": "使用文件 使用文档 Documentation"
    },
    {
      "title": "更新記錄",
      "text": "版本改動與發布說明。",
      "href": "/zh-hant/changelog/",
      "keys": "更新記錄 更新记录 Changelog"
    },
    {
      "title": "隱私說明",
      "text": "日常輸入在本機處理；沒有線上訂閱，也沒有統計 SDK。",
      "href": "/zh-hant/privacy/",
      "keys": "隱私說明 隐私说明 Privacy"
    },
    {
      "title": "開源與致謝",
      "text": "Hufu 原創程式碼 MIT，第三方元件保留各自許可。",
      "href": "/zh-hant/open-source/",
      "keys": "開源與致謝 开源与致谢 Open source"
    }
  ],
  "en": [
    {
      "title": "Home",
      "text": "A macOS input method for Tiger-Code only. Open source, private, built on librime.",
      "href": "/en/",
      "keys": "Home 首页 首頁"
    },
    {
      "title": "Install & download",
      "text": "0.1.0 preview for macOS 15.0+, ad-hoc signed.",
      "href": "/en/download/",
      "keys": "Install download 安装 下載"
    },
    {
      "title": "Vocabulary",
      "text": "The official Tiger-Code tables, word input and custom phrases.",
      "href": "/en/dictionaries/",
      "keys": "Vocabulary 词库 詞庫"
    },
    {
      "title": "Themes",
      "text": "8 palettes rendered by the App, one-click hufu-ime:// import.",
      "href": "/en/themes/",
      "keys": "Themes 主题 主題"
    },
    {
      "title": "Documentation",
      "text": "Add the input method, configure it, word input, migration, AI, uninstall.",
      "href": "/en/docs/",
      "keys": "Documentation docs 文档 文件"
    },
    {
      "title": "Changelog",
      "text": "What changed in each release.",
      "href": "/en/changelog/",
      "keys": "Changelog 更新记录 更新記錄"
    },
    {
      "title": "Privacy",
      "text": "Everyday typing stays on your Mac; no subscriptions, no analytics SDK.",
      "href": "/en/privacy/",
      "keys": "Privacy 隐私 隱私"
    },
    {
      "title": "Open source",
      "text": "Hufu code is MIT; third-party components keep their licences.",
      "href": "/en/open-source/",
      "keys": "Open source 开源 開源"
    }
  ]
};

export const uiCopy: Record<Locale, UiCopy> = {
  "zh": {
    "results": "个结果",
    "lists": "份词表",
    "copied": "已复制",
    "clipboard": "浏览器不允许复制，请手动选择文本。"
  },
  "zh-hant": {
    "results": "個結果",
    "lists": "份詞表",
    "copied": "已複製",
    "clipboard": "瀏覽器不允許複製，請手動選擇文本。"
  },
  "en": {
    "results": "results",
    "lists": "word lists",
    "copied": "Copied",
    "clipboard": "Clipboard unavailable. Please select the text manually."
  }
};

/** JSON-LD node shared by the home and download pages. */
export const software = {
  "@type": "SoftwareApplication",
  "@id": "https://hufu.yufan.dev/#software",
  "name": "Hufu",
  "alternateName": "虎符输入法",
  "applicationCategory": "UtilitiesApplication",
  "applicationSubCategory": "Input method",
  "operatingSystem": "macOS 15.0+",
  "softwareVersion": "0.1.0",
  "datePublished": "2026-10-13",
  "downloadUrl": "https://github.com/syhily/hufu/releases/latest",
  "fileSize": "36.5 MB",
  "releaseNotes": "https://github.com/syhily/hufu/releases",
  "license": "https://github.com/syhily/hufu/blob/main/LICENSE",
  "isAccessibleForFree": true,
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  },
  "description": "虎符输入法，只做虎码的 macOS 输入法。开源，注重隐私，基于 librime。",
  "url": "https://hufu.yufan.dev/",
  "image": "https://hufu.yufan.dev/og.png",
  "publisher": {
    "@id": "https://hufu.yufan.dev/#organization"
  },
  "author": {
    "@id": "https://hufu.yufan.dev/#organization"
  }
};
