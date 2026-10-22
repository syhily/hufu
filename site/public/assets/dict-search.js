/*
 * Tiger-Code lookup: loads /dict/index.json on first input, then matches
 * characters and simplified words by text or by code. No framework.
 */
const MAX_GROUPS = 100;

const STRINGS = {
  zh: {
    loading: '正在加载词表…',
    error: '词表加载失败，请刷新页面重试。',
    count: (n) => `共 ${n} 条`,
    limit: '每类显示前 100 条',
    chars: '单字',
    words: '词汇',
    full: '全码',
    short: '简码',
    copy: '点击复制',
    copied: '已复制',
    copyFailed: '复制失败，请手动选择编码。',
    empty: '没有匹配的字词，试试别的写法或编码。',
  },
  'zh-hant': {
    loading: '正在載入詞表…',
    error: '詞表載入失敗，請重新整理頁面。',
    count: (n) => `共 ${n} 筆`,
    limit: '每類顯示前 100 筆',
    chars: '單字',
    words: '詞彙',
    full: '全碼',
    short: '簡碼',
    copy: '點擊複製',
    copied: '已複製',
    copyFailed: '複製失敗，請手動選取編碼。',
    empty: '沒有符合的字詞，換個寫法或編碼試試。',
  },
  en: {
    loading: 'Loading dictionaries…',
    error: 'Could not load the dictionary index. Reload the page.',
    count: (n) => `${n} ${n === 1 ? 'result' : 'results'}`,
    limit: 'Showing the first 100 per group',
    chars: 'Characters',
    words: 'Words',
    full: 'Full code',
    short: 'Short code',
    copy: 'Click to copy',
    copied: 'Copied',
    copyFailed: 'Copy failed. Select the code and copy it manually.',
    empty: 'No matching characters or words.',
  },
};

const section = document.querySelector('[data-dict-search]');
if (section) {
  const t = STRINGS[section.dataset.locale] || STRINGS.zh;
  const input = section.querySelector('[data-dict-input]');
  const form = section.querySelector('form');
  const status = section.querySelector('[data-dict-status]');
  const results = section.querySelector('[data-dict-results]');
  const empty = section.querySelector('[data-dict-empty]');
  let indexPromise = null;
  let timer = 0;
  let lastSummary = '';

  function loadIndex() {
    if (!indexPromise) {
      status.textContent = t.loading;
      indexPromise = fetch('/dict/index.json')
        .then((response) => {
          if (!response.ok) throw new Error(String(response.status));
          return response.json();
        })
        .then((raw) => {
          const chars = [];
          for (const record of raw.chars) {
            const [text, full, shorts] = record.split('|');
            chars.push({ text, code: full, kind: 'full' });
            if (shorts) {
              for (const code of shorts.split(' ')) chars.push({ text, code, kind: 'short' });
            }
          }
          const words = [];
          for (const record of raw.words) {
            const [text, codes] = record.split('|');
            for (const code of codes.split(' ')) words.push({ text, code, kind: '' });
          }
          return { chars, words };
        })
        .catch((error) => {
          indexPromise = null;
          status.textContent = t.error;
          empty.hidden = true;
          throw error;
        });
    }
    return indexPromise;
  }

  function group(entries, rankFor) {
    const groups = new Map();
    for (const entry of entries) {
      const rank = rankFor(entry);
      if (rank < 0) continue;
      let item = groups.get(entry.text);
      if (!item) {
        item = { text: entry.text, rank, codes: [] };
        groups.set(entry.text, item);
      } else if (rank < item.rank) {
        item.rank = rank;
      }
      if (!item.codes.some((code) => code.code === entry.code)) item.codes.push(entry);
    }
    return [...groups.values()].sort((a, b) => {
      if (a.rank !== b.rank) return a.rank - b.rank;
      if (a.text.length !== b.text.length) return a.text.length - b.text.length;
      return a.text.localeCompare(b.text);
    });
  }

  function search(entries, query, byText) {
    const q = byText ? query : query.toLowerCase();
    return group(entries, (entry) => {
      if (byText) {
        if (entry.text === q) return 0;
        if (entry.text.startsWith(q)) return 1;
        return entry.text.includes(q) ? 2 : -1;
      }
      const code = entry.code.toLowerCase();
      if (code === q) return 0;
      return code.startsWith(q) ? 1 : -1;
    });
  }

  function codeButton(entry) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'dict-code';
    button.dataset.code = entry.code;
    button.title = t.copy;
    button.setAttribute('aria-label', `${t.copy} ${entry.code}`);

    const code = document.createElement('code');
    code.textContent = entry.code;
    button.append(code);

    if (entry.kind) {
      const kind = document.createElement('span');
      kind.className = 'dict-kind';
      kind.textContent = entry.kind === 'full' ? t.full : t.short;
      button.append(kind);
    }
    return button;
  }

  function groupSection(label, items) {
    const block = document.createElement('section');
    block.className = 'dict-group';

    const heading = document.createElement('h3');
    heading.className = 'dict-group-title';
    heading.textContent = `${label} · ${items.length}`;
    block.append(heading);

    const list = document.createElement('ul');
    list.className = 'dict-list';
    for (const item of items.slice(0, MAX_GROUPS)) {
      const row = document.createElement('li');
      row.className = 'dict-row';

      const text = document.createElement('span');
      text.className = 'dict-text';
      text.textContent = item.text;
      row.append(text);

      const codes = document.createElement('span');
      codes.className = 'dict-codes';
      for (const entry of item.codes) codes.append(codeButton(entry));
      row.append(codes);
      list.append(row);
    }
    block.append(list);
    return block;
  }

  function render(query, index) {
    const q = query.trim();
    results.replaceChildren();
    empty.hidden = true;
    if (!q) {
      lastSummary = '';
      status.textContent = '';
      return;
    }

    const byText = /\p{Script=Han}/u.test(q);
    const chars = search(index.chars, q, byText);
    const words = search(index.words, q, byText);
    const total = chars.length + words.length;

    if (!total) {
      lastSummary = '';
      status.textContent = '';
      empty.hidden = false;
      return;
    }

    empty.hidden = true;
    let summary = t.count(total);
    if (chars.length > MAX_GROUPS || words.length > MAX_GROUPS) summary += ` · ${t.limit}`;
    lastSummary = summary;
    status.textContent = summary;

    if (chars.length) results.append(groupSection(t.chars, chars));
    if (words.length) results.append(groupSection(t.words, words));
  }

  function fallbackCopy(value) {
    const area = document.createElement('textarea');
    area.value = value;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.append(area);
    area.select();
    const ok = document.execCommand('copy');
    area.remove();
    if (!ok) throw new Error('copy failed');
  }

  async function copy(button) {
    const code = button.dataset.code;
    try {
      if (navigator.clipboard?.writeText) await navigator.clipboard.writeText(code);
      else fallbackCopy(code);
    } catch {
      try {
        fallbackCopy(code);
      } catch {
        status.textContent = t.copyFailed;
        return;
      }
    }
    button.classList.add('is-copied');
    status.textContent = `${t.copied} ${code}`;
    window.setTimeout(() => {
      button.classList.remove('is-copied');
      status.textContent = lastSummary;
    }, 1400);
  }

  input.addEventListener('input', () => {
    window.clearTimeout(timer);
    timer = window.setTimeout(async () => {
      if (!input.value.trim()) {
        render('', null);
        return;
      }
      try {
        render(input.value, await loadIndex());
      } catch {
        /* loadIndex already reported the failure */
      }
    }, 150);
  });

  form.addEventListener('submit', (event) => event.preventDefault());

  results.addEventListener('click', (event) => {
    const button = event.target.closest('.dict-code');
    if (button) copy(button);
  });
}
