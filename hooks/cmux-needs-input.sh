#!/bin/bash
# Claude Codeが「ユーザーのアクション待ちでブロックしている」ことを
# cmuxのworkspace色（#FF3B30）を信号チャネルとしてカスタムサイドバーに伝える。
#
# 意味論: needs input = ターン実行中に許可プロンプト/質問で停止している状態。
# ターン完了後のidle通知（"Claude is waiting for your input"）は含めない。
# 区別のため、セッションごとの直近フェーズ(running/idle)を状態ファイルに記録する。
#   on  : Notification hookから。フェーズがrunning（=ターン中のダイアログ）の時のみ点灯
#   off : UserPromptSubmit(→running記録) / Stop(→idle記録) から。sentinel色のみクリア
# cmux外では即終了。常にexit 0でClaudeを止めない。

[ -n "$CMUX_BUNDLE_ID" ] || exit 0

mode="${1:-on}"
SENTINEL='#FF3B30'
STATE="$HOME/.claude/cmux-needs-input-state.json"

input=$(cat)
session=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)

cmux_bin="${CMUX_BUNDLED_CLI_PATH:-}"
[ -z "$cmux_bin" ] && cmux_bin="$(command -v cmux 2>/dev/null)"
[ -z "$cmux_bin" ] && [ -x /Applications/cmux.app/Contents/Resources/bin/cmux ] && cmux_bin=/Applications/cmux.app/Contents/Resources/bin/cmux
[ -z "$cmux_bin" ] && exit 0
export CMUX_QUIET=1

# フェーズ記録の更新（off時: submit→running / stop→idle）と、on時の判定
phase=$(python3 - "$mode" "$2" "$session" "$STATE" <<'PY' 2>/dev/null
import json, os, sys, tempfile, time
mode, event, session, state_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    with open(state_path) as f:
        state = json.load(f)
except Exception:
    state = {}
now = time.time()
# 7日以上前のエントリは掃除
state = {k: v for k, v in state.items() if now - v.get('at', 0) < 604800}
result = ''
if session:
    if mode == 'off':
        state[session] = {'phase': 'running' if event == 'submit' else 'idle', 'at': now}
    else:
        result = state.get(session, {}).get('phase', 'idle')
tmp = tempfile.NamedTemporaryFile('w', dir=os.path.dirname(state_path), delete=False)
json.dump(state, tmp)
tmp.close()
os.replace(tmp.name, state_path)
print(result)
PY
)

ws=$("$cmux_bin" identify --json 2>/dev/null | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["caller"]["workspace_ref"])
except Exception:
    pass' 2>/dev/null)
[ -n "$ws" ] || exit 0

if [ "$mode" = "on" ]; then
  # ターン実行中に来た通知（許可プロンプト/質問）のみ点灯。idle通知は無視
  [ "$phase" = "running" ] || exit 0
  "$cmux_bin" workspace-action --action set-color --workspace "$ws" --color "$SENTINEL" >/dev/null 2>&1
else
  current=$("$cmux_bin" workspace list --json 2>/dev/null | python3 -c "
import json, sys
for w in json.load(sys.stdin)['workspaces']:
    if w['ref'] == '$ws':
        print(w.get('custom_color') or '')" 2>/dev/null)
  if [ "$current" = "$SENTINEL" ]; then
    "$cmux_bin" workspace-action --action clear-color --workspace "$ws" >/dev/null 2>&1
  fi
fi
exit 0
