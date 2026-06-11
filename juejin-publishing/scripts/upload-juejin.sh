#!/usr/bin/env bash
# upload-juejin.sh <article-folder> [--publish]
#
# Push an article folder to 掘金 (juejin.cn) as a draft.
# Pass --publish to also publish immediately.
#
# Auth: reads sessionid from ~/.config/juejin/config.json
#   Required: { "session_id": "your-sessionid-here" }
#   Optional: { "category_id": "6809637771511070726", "tag_ids": [] }
#
# Get your session_id:
#   1. Log in to juejin.cn in browser
#   2. DevTools → Application → Cookies → juejin.cn
#   3. Copy the value of "sessionid"
#
# Common category_id values:
#   前端  6809637767543259144
#   后端  6809637769959178254
#   AI    6809637771511070726
#   工具  6809637777629245448
#
# Usage:
#   upload-juejin.sh <article-folder>            # create draft only
#   upload-juejin.sh <article-folder> --publish  # create + publish immediately

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

CONFIG="$HOME/.config/juejin/config.json"
if [[ ! -f "$CONFIG" ]]; then
  echo "error: juejin config not found at $CONFIG" >&2
  echo "" >&2
  echo "Setup:" >&2
  echo "  mkdir -p ~/.config/juejin" >&2
  printf '  echo '"'"'{"session_id":"YOUR_SESSIONID_HERE"}'"'"' > ~/.config/juejin/config.json\n' >&2
  echo "" >&2
  echo "Get sessionid:" >&2
  echo "  1. Log in to juejin.cn" >&2
  echo "  2. DevTools → Application → Cookies → juejin.cn" >&2
  echo "  3. Copy value of 'sessionid'" >&2
  exit 1
fi

cd "$ARTICLE_DIR"

DO_PUBLISH="$DO_PUBLISH" python3 - "$CONFIG" <<'PYEOF'
import sys, json, re, uuid, urllib.request, urllib.error, os

config_path = sys.argv[1]
do_publish = os.environ.get("DO_PUBLISH", "0") == "1"

config = json.load(open(config_path))
session_id = config.get("session_id", "").strip()
if not session_id or session_id == "YOUR_SESSIONID_HERE":
    sys.stderr.write("error: session_id not set in ~/.config/juejin/config.json\n")
    sys.exit(1)

category_id = config.get("category_id", "")
tag_ids     = config.get("tag_ids", [])

meta    = json.load(open("meta.json"))
content = open("article.md").read()
content = re.sub(r'^---\n.*?\n---\n', '', content, count=1, flags=re.DOTALL).strip()

CLIENT_UUID = str(uuid.uuid4())
COMMON_HEADERS = {
    "Cookie":     f"sessionid={session_id}",
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    "Referer":    "https://juejin.cn/",
    "Origin":     "https://juejin.cn",
}
JSON_HEADERS = {**COMMON_HEADERS, "Content-Type": "application/json"}
BASE = "https://api.juejin.cn/content_api/v1"
QS   = f"?aid=2608&uuid={CLIENT_UUID}"

def check_resp(resp):
    if resp.get("err_no", -1) != 0:
        sys.stderr.write(f"API error {resp.get('err_no')}: {resp.get('err_msg', resp)}\n")
        if resp.get("err_no") == 401:
            sys.stderr.write("hint: sessionid expired — refresh from browser DevTools\n")
        sys.exit(1)
    return resp.get("data", {})

def api_post(path, body):
    data = json.dumps(body, ensure_ascii=False).encode()
    req  = urllib.request.Request(BASE + path + QS, data=data, headers=JSON_HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return check_resp(json.loads(r.read()))
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"HTTP {e.code}: {e.read().decode(errors='replace')}\n")
        sys.exit(1)

def upload_image(img_path):
    """Upload a local image to imgur (anonymous), return the public URL.
    Juejin's own image upload API is not publicly documented; imgur is used
    as a reliable free CDN for embedded images.
    Override the client_id via IMGUR_CLIENT_ID env var if rate-limited.
    """
    client_id = os.environ.get("IMGUR_CLIENT_ID", "546c25a59c58ad7")
    boundary = uuid.uuid4().hex
    img_bytes = open(img_path, "rb").read()
    # multipart: field "image" = raw bytes, field "type" = "file"
    def part(name, value, filename=None):
        disp = f'Content-Disposition: form-data; name="{name}"'
        if filename:
            disp += f'; filename="{filename}"'
        return (f"--{boundary}\r\n{disp}\r\nContent-Type: application/octet-stream\r\n\r\n"
                .encode() + (value if isinstance(value, bytes) else value.encode()) + b"\r\n")
    body = part("image", img_bytes, os.path.basename(img_path)) + \
           part("type", b"file") + \
           f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        "https://api.imgur.com/3/upload",
        data=body,
        headers={
            "Authorization": f"Client-ID {client_id}",
            "Content-Type":  f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            resp = json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"imgur upload HTTP {e.code}: {e.read().decode(errors='replace')}\n")
        sys.exit(1)
    if not resp.get("success"):
        sys.stderr.write(f"imgur upload failed: {resp}\n")
        sys.exit(1)
    return resp["data"]["link"]

# 1. Upload embedded images → replace local paths with CDN URLs
for local_path in re.findall(r'!\[.*?\]\((\.\/[\w\-\.]+\.(?:png|jpg|jpeg|gif|webp))\)', content):
    abs_path = os.path.join(os.getcwd(), local_path.lstrip("./"))
    if os.path.exists(abs_path):
        print(f"→ uploading {os.path.basename(abs_path)} ...", file=sys.stderr)
        cdn_url = upload_image(abs_path)
        print(f"   → {cdn_url[:72]}...", file=sys.stderr)
        content = content.replace(local_path, cdn_url)
    else:
        sys.stderr.write(f"  warning: {abs_path} not found, skipping\n")

# 2. Create draft
print("→ creating draft on juejin ...", file=sys.stderr)
draft_data = api_post("/article_draft/create", {
    "title":         meta["title"],
    "brief_content": meta.get("summary", ""),
    "edit_type":     10,        # 10 = markdown editor
    "content":       content,   # HTML version (fallback)
    "mark_content":  content,   # raw markdown — what the editor actually shows
    "cover_image":   "",
    "tag_ids":       tag_ids,
    "category_id":   category_id,
    "theme_ids":     [],
    "link_url":      "",
    "column_ids":    [],
    "draft_id":      "",
})
draft_id = draft_data.get("id") or draft_data.get("draft_id", "")
if not draft_id:
    sys.stderr.write(f"error: no draft_id in response: {draft_data}\n")
    sys.exit(1)

draft_url = f"https://juejin.cn/editor/drafts/{draft_id}"
print(f"   draft_id: {draft_id}", file=sys.stderr)

# Persist to publish.json
pub = {}
if os.path.exists("publish.json"):
    try: pub = json.load(open("publish.json"))
    except Exception: pass
pub.update({"juejin_draft_id": draft_id, "juejin_draft_url": draft_url})
open("publish.json", "w").write(json.dumps(pub, ensure_ascii=False, indent=2))

if not do_publish:
    print("", file=sys.stderr)
    print("✓ draft created", file=sys.stderr)
    print(f"  → {draft_url}", file=sys.stderr)
    print("  (pass --publish to publish immediately)", file=sys.stderr)
    sys.exit(0)

# 2. Publish
print("→ publishing ...", file=sys.stderr)
pub_data = api_post("/article/publish", {
    "draft_id":    draft_id,
    "sync_to_org": False,
    "column_ids":  [],
    "theme_ids":   [],
})
article_id = pub_data.get("article_id", "")
print("", file=sys.stderr)
print("✓ published", file=sys.stderr)
if article_id:
    article_url = f"https://juejin.cn/post/{article_id}"
    pub.update({"juejin_article_id": article_id, "juejin_article_url": article_url})
    open("publish.json", "w").write(json.dumps(pub, ensure_ascii=False, indent=2))
    print(f"  → {article_url}", file=sys.stderr)
PYEOF

# Auto-open in browser (disable with JUEJIN_NO_OPEN=1)
if [[ -z "${JUEJIN_NO_OPEN:-}" ]]; then
  OPEN_URL=$(python3 -c "
import json, sys
try:
    d = json.load(open('$ARTICLE_DIR/publish.json'))
    print(d.get('juejin_article_url') or d.get('juejin_draft_url') or '')
except Exception:
    pass
" 2>/dev/null || true)
  if [[ -n "$OPEN_URL" ]]; then
    open "$OPEN_URL" >/dev/null 2>&1 || xdg-open "$OPEN_URL" >/dev/null 2>&1 || true
    echo "  (opened in browser)" >&2
  fi
fi
