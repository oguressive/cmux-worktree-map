#!/bin/bash
# cmux配下のClaude Codeセッションのcwd（EnterWorktreeでのworktree移動を含む）を
# OSC7エスケープシーケンスで自分のttyへ通知し、cmuxのタブ情報（directory/branch）を最新化する。
# UserPromptSubmit / SessionStart hookから呼ばれる。stdinにhookのJSONが渡る。

# cmux配下でなければ何もしない
[ -n "$CMUX_BUNDLE_ID" ] || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

# hook自身には制御端末がないため、祖先プロセス（claude）を遡ってttyを見つける
pid=$$
tty=""
for _ in 1 2 3 4 5 6; do
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -z "$pid" ] || [ "$pid" -le 1 ]; then break; fi
  t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  case "$t" in
    ttys*) tty="$t"; break ;;
  esac
done
[ -n "$tty" ] || exit 0

printf '\033]7;file://%s%s\033\\' "$(hostname)" "$cwd" > "/dev/$tty" 2>/dev/null
exit 0
