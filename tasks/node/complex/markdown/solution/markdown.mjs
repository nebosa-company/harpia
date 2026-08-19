const HR_RE = /^ *([-*_])( *\1){2,} *$/;
const H_RE = /^(#{1,6}) (.*)$/;
const UL_RE = /^[-*] (.*)$/;
const OL_RE = /^\d+\. (.*)$/;
const QUOTE_RE = /^>/;
const FENCE_RE = /^```(.*)$/;
const FENCE_CLOSE_RE = /^``` *$/;

function escapeHtml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderInline(raw) {
  const escapes = [];
  let s = raw.replace(/\\([\\`*_[\]#()])/g, (_, ch) => {
    escapes.push(ch);
    return `${escapes.length - 1}`;
  });

  s = escapeHtml(s);

  const codes = [];
  s = s.replace(/`([^`]+)`/g, (_, code) => {
    codes.push(code);
    return `${codes.length - 1}`;
  });

  const urls = [];
  s = s.replace(/\[([^\]]*)\]\(([^)\s]*)\)/g, (_, text, url) => {
    urls.push(url);
    return `<a href="${urls.length - 1}">${text}</a>`;
  });

  s = s.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  s = s.replace(/\*([^*]+)\*/g, "<em>$1</em>");

  s = s.replace(/(\d+)/g, (_, i) => `<code>${codes[i]}</code>`);
  s = s.replace(/(\d+)/g, (_, i) => urls[i]);
  s = s.replace(/(\d+)/g, (_, i) => escapeHtml(escapes[i]));
  return s;
}

function startsBlock(line) {
  return (
    FENCE_RE.test(line) ||
    H_RE.test(line) ||
    HR_RE.test(line) ||
    QUOTE_RE.test(line) ||
    UL_RE.test(line) ||
    OL_RE.test(line)
  );
}

function renderBlocks(lines) {
  const out = [];
  const isBlank = (l) => /^\s*$/.test(l);
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    if (isBlank(line)) {
      i += 1;
      continue;
    }

    const fence = FENCE_RE.exec(line);
    if (fence) {
      const info = fence[1].trim();
      i += 1;
      const code = [];
      while (i < lines.length && !FENCE_CLOSE_RE.test(lines[i])) {
        code.push(lines[i]);
        i += 1;
      }
      i += 1; // closing fence (or end of input)
      const cls = info === "" ? "" : ` class="language-${escapeHtml(info)}"`;
      const body = code.length === 0 ? "" : `${escapeHtml(code.join("\n"))}\n`;
      out.push(`<pre><code${cls}>${body}</code></pre>`);
      continue;
    }

    const heading = H_RE.exec(line);
    if (heading) {
      const level = heading[1].length;
      out.push(`<h${level}>${renderInline(heading[2].trim())}</h${level}>`);
      i += 1;
      continue;
    }

    if (HR_RE.test(line)) {
      out.push("<hr />");
      i += 1;
      continue;
    }

    if (QUOTE_RE.test(line)) {
      const inner = [];
      while (i < lines.length && QUOTE_RE.test(lines[i])) {
        inner.push(lines[i].replace(/^> ?/, ""));
        i += 1;
      }
      out.push(`<blockquote>\n${renderBlocks(inner).join("\n")}\n</blockquote>`);
      continue;
    }

    if (UL_RE.test(line)) {
      const items = [];
      while (i < lines.length && !HR_RE.test(lines[i]) && UL_RE.test(lines[i])) {
        items.push(UL_RE.exec(lines[i])[1]);
        i += 1;
      }
      out.push(
        `<ul>\n${items.map((t) => `<li>${renderInline(t)}</li>`).join("\n")}\n</ul>`,
      );
      continue;
    }

    if (OL_RE.test(line)) {
      const items = [];
      while (i < lines.length && OL_RE.test(lines[i])) {
        items.push(OL_RE.exec(lines[i])[1]);
        i += 1;
      }
      out.push(
        `<ol>\n${items.map((t) => `<li>${renderInline(t)}</li>`).join("\n")}\n</ol>`,
      );
      continue;
    }

    const para = [];
    while (i < lines.length && !isBlank(lines[i]) && !startsBlock(lines[i])) {
      para.push(lines[i]);
      i += 1;
    }
    out.push(`<p>${renderInline(para.join("\n"))}</p>`);
  }

  return out;
}

export function renderMarkdown(input) {
  if (typeof input !== "string") {
    throw new TypeError("renderMarkdown: input must be a string");
  }
  const lines = input.replace(/\r\n?/g, "\n").split("\n");
  return renderBlocks(lines).join("\n");
}
