// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import mdx from '@astrojs/mdx';

const REPO = 'https://github.com/syhily/hufu';
const SITE = 'https://hufu.yufan.dev';

// Site-wide structured data: the same graph the previous hand-written site emitted.
const jsonLd = JSON.stringify({
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': `${SITE}/#organization`,
      name: 'syhily',
      url: REPO,
      logo: `${SITE}/icon.png`,
      sameAs: ['https://github.com/syhily'],
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE}/#website`,
      name: 'Hufu',
      alternateName: ['虎符输入法', '虎符輸入法'],
      url: `${SITE}/`,
      inLanguage: 'zh-Hans',
      publisher: { '@id': `${SITE}/#organization` },
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${SITE}/#software`,
      name: 'Hufu',
      alternateName: '虎符输入法',
      applicationCategory: 'UtilitiesApplication',
      applicationSubCategory: 'Input method',
      operatingSystem: 'macOS 15.0+',
      softwareVersion: '0.1.0',
      datePublished: '2026-10-21',
      downloadUrl: `${REPO}/releases/latest`,
      releaseNotes: `${REPO}/releases`,
      license: `${REPO}/blob/main/LICENSE`,
      isAccessibleForFree: true,
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
      description: '虎符输入法，只做虎码的 macOS 输入法。开源，注重隐私，基于 librime。',
      url: `${SITE}/`,
      image: `${SITE}/og.png`,
      publisher: { '@id': `${SITE}/#organization` },
      author: { '@id': `${SITE}/#organization` },
    },
  ],
});

export default defineConfig({
  site: SITE,
  trailingSlash: 'always',
  build: { format: 'directory' },
  integrations: [
    starlight({
      title: '虎符输入法 Hufu',
      description: '只做虎码的 macOS 输入法。开源，注重隐私，基于 librime。',
      logo: {
        light: './src/assets/mark-vermilion.svg',
        dark: './src/assets/mark-white.svg',
        alt: 'Hufu 虎符输入法',
      },
      favicon: '/icon.png',
      social: [{ icon: 'github', label: 'GitHub', href: REPO }],
      editLink: { baseUrl: `${REPO}/edit/main/site/` },
      customCss: ['./src/styles/hufu.css'],
      head: [
        { tag: 'script', attrs: { type: 'application/ld+json' }, content: jsonLd },
        { tag: 'meta', attrs: { property: 'og:image', content: `${SITE}/og.png` } },
        { tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
        { tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
        { tag: 'meta', attrs: { name: 'twitter:image', content: `${SITE}/og.png` } },
      ],
      locales: {
        root: { label: '简体中文', lang: 'zh-Hans' },
        'zh-hant': { label: '繁體中文', lang: 'zh-Hant' },
        en: { label: 'English', lang: 'en' },
      },
      sidebar: [
        {
          label: '安装与下载',
          translations: { 'zh-Hant': '安裝與下載', en: 'Install & download' },
          slug: 'download',
        },
        {
          label: '词库',
          translations: { 'zh-Hant': '詞庫', en: 'Vocabulary' },
          slug: 'dictionaries',
        },
        {
          label: '主题',
          translations: { 'zh-Hant': '主題', en: 'Themes' },
          slug: 'themes',
        },
        {
          label: '使用文档',
          translations: { 'zh-Hant': '使用文件', en: 'Documentation' },
          slug: 'docs',
        },
        {
          label: '更新记录',
          translations: { 'zh-Hant': '更新記錄', en: 'Changelog' },
          slug: 'changelog',
        },
        {
          label: '隐私说明',
          translations: { 'zh-Hant': '隱私說明', en: 'Privacy' },
          slug: 'privacy',
        },
        {
          label: '开源与致谢',
          translations: { 'zh-Hant': '開源與致謝', en: 'Open source' },
          slug: 'open-source',
        },
      ],
    }),
    mdx(),
  ],
});
