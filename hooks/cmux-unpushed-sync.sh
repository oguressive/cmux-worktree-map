#!/bin/bash
# git状態スイープ: どこかのセッションのイベントを契機に、全workspaceのgit状態を
# 一括実測してdescription信号を更新する（定期実行なしのイベント駆動）。
#   未pushコミット (HEAD --not --remotes) -> [名前]
#   未コミット変更 (status --porcelain)   -> (名前)
# descriptionの形式: 「⇡[名前](名前)...」（⇡始まり以外の手動descriptionは触らない）
# 自分の (workspace, cwd) はレジストリに自己登録し、休止中タブの場所も追跡できるようにする。
# PostToolUse(git系/Edit/Write) / Stop / SessionStart から async で呼ばれる。常にexit 0。

[ -n "$CMUX_BUNDLE_ID" ] || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)

# CLI解決順: ①cmux注入の環境変数(起動中アプリと必ず一致) ②アプリ同梱CLI ③PATH(古い野良CLIの可能性があるため最後)
cmux_bin="${CMUX_BUNDLED_CLI_PATH:-}"
[ -z "$cmux_bin" ] && [ -x /Applications/cmux.app/Contents/Resources/bin/cmux ] && cmux_bin=/Applications/cmux.app/Contents/Resources/bin/cmux
[ -z "$cmux_bin" ] && cmux_bin="$(command -v cmux 2>/dev/null)"
[ -z "$cmux_bin" ] && exit 0
export CMUX_QUIET=1

ws=$("$cmux_bin" identify --json 2>/dev/null | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["caller"]["workspace_ref"])
except Exception:
    pass' 2>/dev/null)

python3 - "$ws" "$cwd" "$cmux_bin" <<'PY' 2>/dev/null
import json, os, re, subprocess, sys, tempfile

my_ws, my_cwd, cmux = sys.argv[1], sys.argv[2], sys.argv[3]
REG = os.path.expanduser('~/.claude/cmux-git-registry.json')

try:
    r = subprocess.run([cmux, 'workspace', 'list', '--json'],
                       capture_output=True, text=True, timeout=10)
    workspaces = json.loads(r.stdout)['workspaces']
except Exception:
    sys.exit(0)

# レジストリ読込 + 自己登録 + 消滅ディレクトリの掃除
try:
    with open(REG) as f:
        reg = json.load(f)
except Exception:
    reg = {}
if my_ws and my_cwd and os.path.isdir(my_cwd):
    reg.setdefault(my_ws, [])
    if my_cwd not in reg[my_ws]:
        reg[my_ws].append(my_cwd)
live_refs = {w['ref'] for w in workspaces}
reg = {ws: [d for d in dirs if os.path.isdir(d)]
       for ws, dirs in reg.items() if ws in live_refs}
reg = {ws: dirs for ws, dirs in reg.items() if dirs}
tmp = tempfile.NamedTemporaryFile('w', dir=os.path.dirname(REG), delete=False)
json.dump(reg, tmp, ensure_ascii=False)
tmp.close()
os.replace(tmp.name, REG)

# ディレクトリ単位のgit状態（同一ディレクトリは1回だけ実測）
cache = {}
def git_state(d):
    if d in cache:
        return cache[d]
    r = subprocess.run(['git', '-C', d, 'rev-list', '--count', 'HEAD', '--not', '--remotes'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        cache[d] = None
        return None
    unpushed = int(r.stdout.strip() or 0)
    s = subprocess.run(['git', '-C', d, 'status', '--porcelain'], capture_output=True, text=True)
    cache[d] = (unpushed, bool(s.stdout.strip()))
    return cache[d]

for w in workspaces:
    ref = w['ref']
    cur = w.get('description') or ''
    if cur and not cur.startswith('⇡'):
        continue  # 手動descriptionは触らない
    dirs = set(reg.get(ref, []))
    d = w.get('current_directory')
    if d and os.path.isdir(d):
        dirs.add(d)
    up, dt = set(), set()
    for d in dirs:
        st = git_state(d)
        if st is None:
            continue
        name = d.rstrip('/').rsplit('/', 1)[-1]
        if st[0] > 0:
            up.add(name)
        if st[1]:
            dt.add(name)
    body = ''.join(f'[{n}]' for n in sorted(up)) + ''.join(f'({n})' for n in sorted(dt))
    desc = '⇡' + body if body else ''
    if desc == cur:
        continue
    if desc:
        subprocess.run([cmux, 'workspace-action', '--action', 'set-description',
                        '--workspace', ref, '--description', desc], capture_output=True)
    else:
        subprocess.run([cmux, 'workspace-action', '--action', 'clear-description',
                        '--workspace', ref], capture_output=True)
PY
exit 0
