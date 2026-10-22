/** 内置配色，数据源：SharedSupport/hufu.yaml 的 preset_color_schemes 与 style/hufu。 */

export interface Theme {
  id: string;
  name: string;
  tag: 'light' | 'dark';
  colors: Record<string, string>;
  layout: Record<string, number>;
}

export const themes: Theme[] = [
  {
    id: "hufu_light",
    name: "虎符 · 浅色",
    tag: "light",
    colors: {
      "back_color": "0XF5FCFCFB",
      "border_color": "0X14242321",
      "preedit_back_color": "0X00000000",
      "text_color": "0XFF6B6A67",
      "hilited_text_color": "0XFF242321",
      "hilited_back_color": "0X14242321",
      "candidate_text_color": "0XFF242321",
      "comment_text_color": "0XFF6B6A67",
      "label_color": "0XFF8A8986",
      "hilited_candidate_back_color": "0XFFB64032",
      "hilited_candidate_text_color": "0XFFFFFFFF",
      "hilited_comment_text_color": "0XE6FFFFFF",
      "hilited_candidate_label_color": "0XE6FFFFFF"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "hufu_dark",
    name: "虎符 · 深色",
    tag: "dark",
    colors: {
      "back_color": "0XF21E1E20",
      "border_color": "0X1FFFFFFF",
      "preedit_back_color": "0X00000000",
      "text_color": "0XFFA3A3A0",
      "hilited_text_color": "0XFFF2F2F0",
      "hilited_back_color": "0X29FFFFFF",
      "candidate_text_color": "0XFFF2F2F0",
      "comment_text_color": "0XFFA3A3A0",
      "label_color": "0XFF8E8E8B",
      "hilited_candidate_back_color": "0XFFC4503F",
      "hilited_candidate_text_color": "0XFFFFFFFF",
      "hilited_comment_text_color": "0XE6FFFFFF",
      "hilited_candidate_label_color": "0XE6FFFFFF"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "graphite",
    name: "石墨",
    tag: "light",
    colors: {
      "back_color": "0XF5F5F5F4",
      "border_color": "0X1A000000",
      "text_color": "0XFF57534E",
      "hilited_text_color": "0XFF1C1917",
      "hilited_back_color": "0X14000000",
      "candidate_text_color": "0XFF292524",
      "comment_text_color": "0XFFA8A29E",
      "label_color": "0XFFA8A29E",
      "hilited_candidate_back_color": "0XFF292524",
      "hilited_candidate_text_color": "0XFFFAFAF9",
      "hilited_comment_text_color": "0XFFD6D3D1",
      "hilited_candidate_label_color": "0XFFD6D3D1"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "midnight",
    name: "午夜",
    tag: "dark",
    colors: {
      "back_color": "0XF20B1120",
      "border_color": "0X2638BDF8",
      "text_color": "0XFF94A3B8",
      "hilited_text_color": "0XFFE2E8F0",
      "hilited_back_color": "0X3338BDF8",
      "candidate_text_color": "0XFFE2E8F0",
      "comment_text_color": "0XFF64748B",
      "label_color": "0XFF64748B",
      "hilited_candidate_back_color": "0XFF0EA5E9",
      "hilited_candidate_text_color": "0XFF0B1120",
      "hilited_comment_text_color": "0XFF0C4A6E",
      "hilited_candidate_label_color": "0XFF0C4A6E"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "sakura",
    name: "樱花",
    tag: "light",
    colors: {
      "back_color": "0XF5FFF5F7",
      "border_color": "0X1FDB2777",
      "text_color": "0XFF9D174D",
      "hilited_text_color": "0XFF831843",
      "hilited_back_color": "0X1FEC4899",
      "candidate_text_color": "0XFF500724",
      "comment_text_color": "0XFFF472B6",
      "label_color": "0XFFF9A8D4",
      "hilited_candidate_back_color": "0XFFEC4899",
      "hilited_candidate_text_color": "0XFFFFFFFF",
      "hilited_comment_text_color": "0XFFFCE7F3",
      "hilited_candidate_label_color": "0XFFFCE7F3"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "matcha",
    name: "抹茶",
    tag: "light",
    colors: {
      "back_color": "0XF5F4F9F1",
      "border_color": "0X1F4D7C0F",
      "text_color": "0XFF4D7C0F",
      "hilited_text_color": "0XFF365314",
      "hilited_back_color": "0X1F65A30D",
      "candidate_text_color": "0XFF1A2E05",
      "comment_text_color": "0XFF84A36B",
      "label_color": "0XFF9CB88A",
      "hilited_candidate_back_color": "0XFF4D7C0F",
      "hilited_candidate_text_color": "0XFFF7FEE7",
      "hilited_comment_text_color": "0XFFD9F99D",
      "hilited_candidate_label_color": "0XFFD9F99D"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "nord",
    name: "北境",
    tag: "dark",
    colors: {
      "back_color": "0XF22E3440",
      "border_color": "0X1FD8DEE9",
      "text_color": "0XFFD8DEE9",
      "hilited_text_color": "0XFFECEFF4",
      "hilited_back_color": "0X3388C0D0",
      "candidate_text_color": "0XFFE5E9F0",
      "comment_text_color": "0XFF81A1C1",
      "label_color": "0XFF81A1C1",
      "hilited_candidate_back_color": "0XFF88C0D0",
      "hilited_candidate_text_color": "0XFF2E3440",
      "hilited_comment_text_color": "0XFF3B4252",
      "hilited_candidate_label_color": "0XFF3B4252"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
  {
    id: "paper",
    name: "纸墨（竖排适用）",
    tag: "light",
    colors: {
      "back_color": "0XFAFAF7F0",
      "border_color": "0X26000000",
      "text_color": "0XFF78716C",
      "hilited_text_color": "0XFF1C1917",
      "hilited_back_color": "0X1A92400E",
      "candidate_text_color": "0XFF1C1917",
      "comment_text_color": "0XFFA8A29E",
      "label_color": "0XFFB45309",
      "hilited_candidate_back_color": "0XFFB91C1C",
      "hilited_candidate_text_color": "0XFFFFFBEB",
      "hilited_comment_text_color": "0XFFFDE68A",
      "hilited_candidate_label_color": "0XFFFDE68A"
    },
    layout: {"corner_radius": 10, "hilited_corner_radius": 6, "border_width": 7, "border_height": 6, "spacing": 8, "line_spacing": 4, "font_point": 17, "label_font_point": 13, "comment_font_point": 13},
  },
];

/** Keys the YAML presets leave out fall back to the panel's RIME defaults (transparent preedit). */
const colorDefaults: Record<string, string> = { preedit_back_color: '0X00000000' };

function allColors(theme: Theme): Record<string, string> {
  return { ...colorDefaults, ...theme.colors };
}

type Rgba = [number, number, number, number];

function rgba(value: string): Rgba {
  const n = Number.parseInt(value.replace(/^0X/i, ''), 16);
  return [((n >>> 16) & 0xff) / 255, ((n >>> 8) & 0xff) / 255, (n & 0xff) / 255, (n >>> 24) / 255];
}

function blend(fg: Rgba, bg: Rgba): Rgba {
  const alpha = fg[3] + bg[3] * (1 - fg[3]);
  if (!alpha) return [0, 0, 0, 0];
  const channel = (i: number) => (fg[i] * fg[3] + bg[i] * bg[3] * (1 - fg[3])) / alpha;
  return [channel(0), channel(1), channel(2), alpha];
}

function luminance(color: Rgba): number {
  const linear = (value: number) =>
    value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  return 0.2126 * linear(color[0]) + 0.7152 * linear(color[1]) + 0.0722 * linear(color[2]);
}

function ratio(foreground: Rgba, background: Rgba): number {
  const [light, dark] = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (light + 0.05) / (dark + 0.05);
}

/** 与旧站 theme-geometry 相同的算法：背景叠在中灰上，取候选与高亮候选两处的最低对比度。 */
export function contrastOf(theme: Theme): number {
  const colors = allColors(theme);
  const background = blend(rgba(colors.back_color), [0.5, 0.5, 0.5, 1]);
  const highlighted = blend(rgba(colors.hilited_candidate_back_color), background);
  const value = Math.min(
    ratio(blend(rgba(colors.candidate_text_color), background), background),
    ratio(blend(rgba(colors.hilited_candidate_text_color), highlighted), highlighted),
  );
  return Math.round(value * 100) / 100;
}

/** hufu-ime:// theme package: canonical JSON (sorted keys, no whitespace), base64url, no padding. */
export function payload(theme: Theme): string {
  const colors = allColors(theme);
  const pack = {
    author: 'Hufu',
    colors: Object.fromEntries(Object.keys(colors).sort().map((key) => [key, colors[key]])),
    format: 'hufu-theme',
    id: theme.id,
    layout: Object.fromEntries(Object.keys(theme.layout).sort().map((key) => [key, theme.layout[key]])),
    name: theme.name,
    version: 2,
  };
  const json = JSON.stringify(pack);
  return Buffer.from(json, 'utf8').toString('base64url');
}

export function installLink(theme: Theme): string {
  return `hufu-ime://theme?v=2&d=${payload(theme)}`;
}

/** The YAML a user can paste into hufu/imported/hufu.custom.yaml. */
export function yamlSnippet(theme: Theme): string {
  const colors = allColors(theme);
  const colorLines = Object.keys(colors).sort().map((key) => `      ${key}: ${colors[key]}`).join('\n');
  const layout = Object.keys(theme.layout).sort().map((key) => `      ${key}: ${theme.layout[key]}`).join('\n');
  return [
    'patch:',
    '  preset_color_schemes:',
    `    ${theme.id}:`,
    `      name: "${theme.name}"`,
    '      author: Hufu',
    '      color_format: argb',
    colorLines,
    layout,
  ].join('\n');
}
