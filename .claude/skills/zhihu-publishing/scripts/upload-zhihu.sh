#!/usr/bin/env bash
# upload-zhihu.sh <article-folder> [--publish]
#
# Push an article folder to 知乎 (zhihu.com) as a draft, optionally publish.
# Zhihu stores article body as HTML — this script converts article.md → HTML
# (stdlib only, no pandoc/markdown dependency) before posting.
#
# Flow (all under your own account via z_c0 cookie):
#   1. POST   zhuanlan.zhihu.com/api/articles/drafts          → create draft, get id
#   2. PATCH  zhuanlan.zhihu.com/api/articles/{id}/draft       → set title + HTML content
#   3. PUT    zhuanlan.zhihu.com/api/articles/{id}/publish     → publish (only with --publish)
#
# Auth: ~/.config/zhihu/config.json
#   Required: { "z_c0": "your-z_c0-token" }
#   Recommended (more reliable — Zhihu write APIs want _xsrf):
#     { "cookie": "<full cookie string copied from browser>" }
#   If "cookie" is present it is used verbatim and _xsrf is auto-extracted
#   for the x-xsrftoken header. Otherwise only z_c0 is sent.
#
# Get these: log in to zhihu.com → DevTools (F12) → Application → Cookies →
#   https://www.zhihu.com → copy z_c0 value (or the whole Cookie request header).
#
# Usage:
#   upload-zhihu.sh <article-folder>            # create/update draft only
#   upload-zhihu.sh <article-folder> --publish  # create/update + publish

set -euo pipefail

ARTICLE_DIR="${1:-$(pwd)}"
[[ -d "$ARTICLE_DIR" ]] || { echo "error: not a directory: $ARTICLE_DIR" >&2; exit 1; }
ARTICLE_DIR="$(cd "$ARTICLE_DIR" && pwd)"

DO_PUBLISH=0
for arg in "${@:2}"; do
  [[ "$arg" == "--publish" ]] && DO_PUBLISH=1
done

for f in "$ARTICLE_DIR/meta.json" "$ARTICLE_DIR/article.md"; do
  [[ -f "$f" ]] || { echo "error: missing $f" >&2; exit 1; }
done

CONFIG="$HOME/.config/zhihu/config.json"
if [[ ! -f "$CONFIG" ]]; then
  echo "error: zhihu config not found at $CONFIG" >&2
  echo "" >&2
  echo "Setup:" >&2
  echo "  mkdir -p ~/.config/zhihu" >&2
  printf '  echo '"'"'{"z_c0":"YOUR_Z_C0_TOKEN_HERE"}'"'"' > ~/.config/zhihu/config.json\n' >&2
  echo "" >&2
  echo "Get z_c0:" >&2
  echo "  1. Log in to zhihu.com" >&2
  echo "  2. DevTools (F12) → Application → Cookies → https://www.zhihu.com" >&2
  echo "  3. Copy the value of 'z_c0' (or the whole Cookie header → use \"cookie\" key)" >&2
  exit 1
fi

cd "$ARTICLE_DIR"

DO_PUBLISH="$DO_PUBLISH" python3 - "$CONFIG" <<'PYEOF'
import sys, json, re, uuid, html, urllib.request, urllib.error, os, http.cookiejar

config_path = sys.argv[1]
do_publish  = os.environ.get("DO_PUBLISH", "0") == "1"

config = json.load(open(config_path))
z_c0        = (config.get("z_c0") or "").strip()
cookie_full = (config.get("cookie") or "").strip()

if not z_c0 and not cookie_full:
    sys.stderr.write("error: set z_c0 (or full cookie) in ~/.config/zhihu/config.json\n")
    sys.exit(1)
if z_c0 == "YOUR_Z_C0_TOKEN_HERE":
    sys.stderr.write("error: z_c0 still a placeholder — paste your real token\n")
    sys.exit(1)

# Build the Cookie header. Full cookie string wins (carries _xsrf etc.).
if cookie_full:
    cookie_header = cookie_full
    if z_c0 and "z_c0=" not in cookie_full:
        cookie_header = f"z_c0={z_c0}; " + cookie_header
else:
    cookie_header = f"z_c0={z_c0}"

# Extract _xsrf for the x-xsrftoken header (required by Zhihu write APIs).
m = re.search(r'_xsrf=([^;]+)', cookie_header)
xsrf = m.group(1).strip() if m else ""

HEADERS = {
    "Cookie":           cookie_header,
    "User-Agent":       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Referer":          "https://zhuanlan.zhihu.com/write",
    "Origin":           "https://zhuanlan.zhihu.com",
    "x-requested-with": "fetch",
    "Accept":           "*/*",
}
if xsrf:
    HEADERS["x-xsrftoken"] = xsrf

# ---------------------------------------------------------------------------
# Minimal Markdown → HTML for the subset STYLE.md produces.
# Handles: fenced code, ## / ### headings, blockquote, ul/ol lists, tables,
# hr, paragraphs, and inline **bold**, `code`, [link](url), ![img](url).
# ---------------------------------------------------------------------------
def esc(s):
    return html.escape(s, quote=False)

INLINE_CODE = re.compile(r'`([^`]+)`')
BOLD        = re.compile(r'\*\*([^*]+)\*\*')
IMG         = re.compile(r'!\[([^\]]*)\]\(([^)]+)\)')
LINK        = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')

def inline(text):
    # Protect inline code spans first so their contents aren't further parsed.
    spans = []
    def stash(m):
        spans.append(f"<code>{esc(m.group(1))}</code>")
        return f"\x00{len(spans)-1}\x00"
    text = INLINE_CODE.sub(stash, text)
    text = esc(text)
    text = IMG.sub(lambda m: f'<img src="{m.group(2)}" alt="{m.group(1)}"/>', text)
    text = LINK.sub(lambda m: f'<a href="{m.group(2)}">{m.group(1)}</a>', text)
    text = BOLD.sub(lambda m: f'<b>{m.group(1)}</b>', text)
    text = re.sub(r'\x00(\d+)\x00', lambda m: spans[int(m.group(1))], text)
    return text

def md_to_html(md):
    md = re.sub(r'^---\n.*?\n---\n', '', md, count=1, flags=re.DOTALL)  # strip frontmatter
    lines = md.split("\n")
    out, i, n = [], 0, len(lines)

    def flush_para(buf):
        if buf:
            out.append("<p>" + inline(" ".join(buf).strip()) + "</p>")
            buf.clear()

    para = []
    while i < n:
        line = lines[i]

        # fenced code block
        fence = re.match(r'^```(\w*)\s*$', line)
        if fence:
            flush_para(para)
            lang = fence.group(1) or "text"
            code, i = [], i + 1
            while i < n and not re.match(r'^```\s*$', lines[i]):
                code.append(lines[i]); i += 1
            i += 1  # skip closing fence
            out.append(f'<pre lang="{lang}"><code>' + esc("\n".join(code)) + "</code></pre>")
            continue

        # heading (## / ###). Zhihu body has no h1.
        h = re.match(r'^(#{2,3})\s+(.*)$', line)
        if h:
            flush_para(para)
            lvl = len(h.group(1))
            out.append(f"<h{lvl}>" + inline(h.group(2).strip()) + f"</h{lvl}>")
            i += 1; continue

        # hr
        if re.match(r'^(-{3,}|\*{3,})\s*$', line):
            flush_para(para)
            out.append("<hr/>"); i += 1; continue

        # blockquote (consecutive > lines)
        if re.match(r'^>\s?', line):
            flush_para(para)
            quote = []
            while i < n and re.match(r'^>\s?', lines[i]):
                quote.append(re.sub(r'^>\s?', '', lines[i])); i += 1
            out.append("<blockquote>" + inline(" ".join(quote).strip()) + "</blockquote>")
            continue

        # table (header row + |---| separator)
        if "|" in line and i + 1 < n and re.match(r'^\s*\|?[\s:|-]+\|?\s*$', lines[i+1]) and "-" in lines[i+1]:
            flush_para(para)
            def cells(row):
                row = row.strip().strip("|")
                return [c.strip() for c in row.split("|")]
            header = cells(line)
            i += 2
            rows = []
            while i < n and "|" in lines[i] and lines[i].strip():
                rows.append(cells(lines[i])); i += 1
            t = ["<table><thead><tr>"]
            t += [f"<th>{inline(c)}</th>" for c in header]
            t.append("</tr></thead><tbody>")
            for r in rows:
                t.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
            t.append("</tbody></table>")
            out.append("".join(t)); continue

        # unordered list
        if re.match(r'^[-*+]\s+', line):
            flush_para(para)
            items = []
            while i < n and re.match(r'^[-*+]\s+', lines[i]):
                items.append(re.sub(r'^[-*+]\s+', '', lines[i])); i += 1
            out.append("<ul>" + "".join(f"<li>{inline(it)}</li>" for it in items) + "</ul>")
            continue

        # ordered list
        if re.match(r'^\d+\.\s+', line):
            flush_para(para)
            items = []
            while i < n and re.match(r'^\d+\.\s+', lines[i]):
                items.append(re.sub(r'^\d+\.\s+', '', lines[i])); i += 1
            out.append("<ol>" + "".join(f"<li>{inline(it)}</li>" for it in items) + "</ol>")
            continue

        # standalone image line → figure
        im = re.match(r'^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$', line)
        if im:
            flush_para(para)
            out.append(f'<figure><img src="{im.group(2)}" alt="{im.group(1)}"/></figure>')
            i += 1; continue

        # blank → paragraph break
        if not line.strip():
            flush_para(para); i += 1; continue

        para.append(line.strip()); i += 1

    flush_para(para)
    return "\n".join(out)

# ---------------------------------------------------------------------------
def check(resp_bytes):
    try:
        resp = json.loads(resp_bytes)
    except Exception:
        sys.stderr.write(f"non-JSON response: {resp_bytes[:300]!r}\n"); sys.exit(1)
    if isinstance(resp, dict) and "error" in resp:
        err = resp["error"]
        sys.stderr.write(f"API error {err.get('code')}: {err.get('message')}\n")
        if err.get("code") in (100, 401, 4031):
            sys.stderr.write("hint: z_c0/cookie expired or missing _xsrf — refresh from browser DevTools\n")
        sys.exit(1)
    return resp

def request(method, url, body=None):
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    h = dict(HEADERS)
    if data is not None:
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            # Zhihu PATCH /draft and PUT /publish return 200 with an empty body
            # on success — only POST /drafts returns JSON. Treat empty 2xx as OK.
            if not raw.strip():
                return {}
            return check(raw)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        sys.stderr.write(f"HTTP {e.code} {method} {url}\n{body[:400]}\n")
        # If the body is a Zhihu JSON error, check() prints it nicely and exits.
        check(body.encode())
        sys.exit(1)

def _png_size(raw):
    """(width, height) for a PNG byte string, else (0, 0). No PIL needed."""
    if raw[:8] == b"\x89PNG\r\n\x1a\n" and raw[12:16] == b"IHDR":
        return int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big")
    return 0, 0

def upload_image(img_path):
    """Upload a local image to ZHIHU'S OWN CDN and return a picx.zhimg.com URL.

    Zhihu silently strips any <img> whose src is not on its own CDN (imgur,
    etc. vanish on save), so we must use Zhihu's native pipeline:
      1. POST api.zhihu.com/images {image_hash, source}  → object_key + OSS STS token
      2. PUT the bytes to Aliyun OSS (bucket zhihu-pics @ oss-cn-beijing)
      3. reference https://picx.zhimg.com/{object_key}.{ext} — Zhihu recognises
         the object_key and rewrites it to its signed pic-private CDN URL.
    Returns the picx URL, or None on failure (caller leaves the local path)."""
    import hashlib, hmac, base64, time
    from email.utils import formatdate
    raw = open(img_path, "rb").read()
    md5 = hashlib.md5(raw).hexdigest()
    ext = (os.path.splitext(img_path)[1].lower().lstrip(".") or "png")
    ctype = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
             "gif": "image/gif", "webp": "image/webp"}.get(ext, "image/png")
    url_ext = "jpg" if ext == "jpeg" else ext

    # Zhihu's /images response shape is inconsistent: a fresh image carries
    # upload_token + object_key; an already-known one sometimes carries only
    # image_id (recover object_key from its status src), and occasionally the
    # status isn't ready yet on the first poll. Retry the whole prepare→recover
    # a few times so a transient miss doesn't drop the image.
    object_key = None
    for attempt in range(4):
        # 1. prepare — ask Zhihu for an upload token / object_key
        prep = request("POST", "https://api.zhihu.com/images",
                       {"image_hash": md5, "source": "article"})
        uf = prep.get("upload_file", {}) if isinstance(prep, dict) else {}
        image_id   = uf.get("image_id")
        object_key = uf.get("object_key")
        token = prep.get("upload_token") if isinstance(prep, dict) else None

        # 2. PUT bytes to Aliyun OSS (Zhihu's bucket). Harmless if already there.
        if token and object_key:
            date = formatdate(usegmt=True)
            sts  = token["access_token"]
            canon = f"PUT\n\n{ctype}\n{date}\nx-oss-security-token:{sts}\n/zhihu-pics/{object_key}"
            sig = base64.b64encode(
                hmac.new(token["access_key"].encode(), canon.encode(), hashlib.sha1).digest()).decode()
            oh = {"Date": date, "Content-Type": ctype, "x-oss-security-token": sts,
                  "Authorization": f"OSS {token['access_id']}:{sig}"}
            oreq = urllib.request.Request(
                f"https://zhihu-pics.oss-cn-beijing.aliyuncs.com/{object_key}",
                data=raw, headers=oh, method="PUT")
            try:
                urllib.request.urlopen(oreq, timeout=60)
            except urllib.error.HTTPError as e:
                sys.stderr.write(f"  warning: OSS PUT {e.code} for {object_key}: "
                                 f"{e.read().decode(errors='replace')[:200]}\n")

        # 3. If prepare gave no object_key, recover it from the image status src.
        if not object_key and image_id:
            st = request("GET", f"https://api.zhihu.com/images/{image_id}")
            m = re.search(r'(v2-[0-9a-f]+)', st.get("src", "") if isinstance(st, dict) else "")
            object_key = m.group(1) if m else None

        if object_key:
            break
        if attempt < 3:
            time.sleep(1.5)

    if not object_key:
        sys.stderr.write(f"  warning: no object_key for {os.path.basename(img_path)} "
                         f"after retries, skipping\n")
        return None
    return f"https://picx.zhimg.com/{object_key}.{url_ext}"

# --- load article + meta ----------------------------------------------------
meta = json.load(open("meta.json"))
md   = open("article.md").read()

# Upload local images → swap paths to CDN URLs (in the markdown, pre-conversion)
for local_path in re.findall(r'!\[.*?\]\((\.\/[\w\-\.]+\.(?:png|jpg|jpeg|gif|webp))\)', md):
    abs_path = os.path.join(os.getcwd(), local_path.lstrip("./"))
    if os.path.exists(abs_path):
        print(f"→ uploading {os.path.basename(abs_path)} ...", file=sys.stderr)
        url = upload_image(abs_path)
        if url:
            print(f"   → {url[:72]}...", file=sys.stderr)
            md = md.replace(local_path, url)
        else:
            sys.stderr.write(f"  warning: upload failed for {os.path.basename(abs_path)}; "
                             f"leaving local path (image will be missing in draft)\n")
    else:
        sys.stderr.write(f"  warning: {abs_path} not found, skipping\n")

content_html = md_to_html(md)
title = meta["title"]

# Cover / title image — upload cover.png to Zhihu's CDN. The draft write key is
# camelCase "titleImage" (snake_case "title_image" is read-only output).
title_image_url, title_w, title_h = "", 0, 0
cover_path = os.path.join(os.getcwd(), "cover.png")
if os.path.exists(cover_path):
    print("→ uploading cover ...", file=sys.stderr)
    title_image_url = upload_image(cover_path) or ""
    title_w, title_h = _png_size(open(cover_path, "rb").read())
    if title_image_url:
        print(f"   → {title_image_url[:72]}...", file=sys.stderr)

# Resume an existing draft if we created one before.
pub = {}
if os.path.exists("publish.json"):
    try: pub = json.load(open("publish.json"))
    except Exception: pass
draft_id = str(pub.get("zhihu_article_id") or pub.get("zhihu_draft_id") or "").strip()

BASE = "https://zhuanlan.zhihu.com/api/articles"

# 1. Create draft (only if we don't have one yet)
if not draft_id:
    print("→ creating draft on zhihu ...", file=sys.stderr)
    d = request("POST", f"{BASE}/drafts", {"title": title, "delta_time": 0})
    draft_id = str(d.get("id") or d.get("article", {}).get("id") or "")
    if not draft_id:
        sys.stderr.write(f"error: no draft id in response: {d}\n"); sys.exit(1)
    print(f"   draft_id: {draft_id}", file=sys.stderr)

# 2. PATCH title + HTML content
print("→ writing content ...", file=sys.stderr)
patch_body = {
    "title":             title,
    "content":           content_html,
    "table_of_contents": False,
    "delta_time":        0,
    "can_reward":        False,
}
if title_image_url:
    patch_body["titleImage"]       = title_image_url
    patch_body["title_image_size"] = {"width": title_w, "height": title_h}
request("PATCH", f"{BASE}/{draft_id}/draft", patch_body)

draft_url = f"https://zhuanlan.zhihu.com/p/{draft_id}/edit"
pub.update({"zhihu_draft_id": draft_id, "zhihu_draft_url": draft_url})
open("publish.json", "w").write(json.dumps(pub, ensure_ascii=False, indent=2))

if not do_publish:
    print("", file=sys.stderr)
    print("✓ draft saved", file=sys.stderr)
    print(f"  → {draft_url}", file=sys.stderr)
    print("  (pass --publish to publish immediately)", file=sys.stderr)
    sys.exit(0)

# 3. Publish
print("→ publishing ...", file=sys.stderr)
request("PUT", f"{BASE}/{draft_id}/publish", {})
article_url = f"https://zhuanlan.zhihu.com/p/{draft_id}"
pub.update({"zhihu_article_id": draft_id, "zhihu_article_url": article_url})
open("publish.json", "w").write(json.dumps(pub, ensure_ascii=False, indent=2))
print("", file=sys.stderr)
print("✓ published", file=sys.stderr)
print(f"  → {article_url}", file=sys.stderr)
PYEOF

# Auto-open in browser (disable with ZHIHU_NO_OPEN=1)
if [[ -z "${ZHIHU_NO_OPEN:-}" ]]; then
  OPEN_URL=$(python3 -c "
import json
try:
    d = json.load(open('$ARTICLE_DIR/publish.json'))
    print(d.get('zhihu_article_url') or d.get('zhihu_draft_url') or '')
except Exception:
    pass
" 2>/dev/null || true)
  if [[ -n "$OPEN_URL" ]]; then
    open "$OPEN_URL" >/dev/null 2>&1 || xdg-open "$OPEN_URL" >/dev/null 2>&1 || true
    echo "  (opened in browser)" >&2
  fi
fi
