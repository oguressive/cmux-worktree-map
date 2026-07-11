#!/bin/bash
# cmux-worktree-map installer
# - Copies the sidebar to ~/.config/cmux/sidebars/
# - Copies hook scripts to ~/.claude/hooks/
# - Merges hook registrations into ~/.claude/settings.json (existing hooks are preserved)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SIDEBAR_DIR="$HOME/.config/cmux/sidebars"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "==> Installing sidebar"
mkdir -p "$SIDEBAR_DIR"
cp "$REPO_DIR/sidebars/worktrees.swift" "$SIDEBAR_DIR/worktrees.swift"

echo "==> Installing hooks"
mkdir -p "$HOOKS_DIR"
for f in cmux-osc7-cwd.sh cmux-needs-input.sh cmux-unpushed-sync.sh; do
  cp "$REPO_DIR/hooks/$f" "$HOOKS_DIR/$f"
  chmod +x "$HOOKS_DIR/$f"
done

echo "==> Merging hook registrations into $SETTINGS"
python3 - "$SETTINGS" "$HOOKS_DIR" <<'PY'
import json, os, shutil, sys, time

settings_path, hooks_dir = sys.argv[1], sys.argv[2]

def cmd(name, args='', extra=None):
    c = f'{hooks_dir}/{name}' + (f' {args}' if args else '')
    d = {'type': 'command', 'command': c}
    if extra:
        d.update(extra)
    return d

WANTED = {
    'SessionStart': [
        (None, cmd('cmux-osc7-cwd.sh')),
        (None, cmd('cmux-unpushed-sync.sh', extra={'async': True})),
    ],
    'UserPromptSubmit': [
        (None, cmd('cmux-osc7-cwd.sh')),
        (None, cmd('cmux-needs-input.sh', 'off submit')),
    ],
    'Stop': [
        (None, cmd('cmux-needs-input.sh', 'off stop')),
        (None, cmd('cmux-unpushed-sync.sh', extra={'async': True})),
    ],
    'Notification': [
        (None, cmd('cmux-needs-input.sh', 'on')),
    ],
    'PostToolUse': [
        ('Bash', cmd('cmux-unpushed-sync.sh', extra={'if': 'Bash(git *)', 'async': True})),
        ('Write|Edit', cmd('cmux-unpushed-sync.sh', extra={'async': True})),
    ],
}

settings = {}
if os.path.exists(settings_path):
    shutil.copy(settings_path, settings_path + f'.bak.{int(time.time())}')
    with open(settings_path) as f:
        settings = json.load(f)

hooks = settings.setdefault('hooks', {})
added = 0
for event, entries in WANTED.items():
    groups = hooks.setdefault(event, [])
    for matcher, hook in entries:
        group = None
        for g in groups:
            if g.get('matcher') == matcher or (matcher is None and 'matcher' not in g):
                group = g
                break
        if group is None:
            group = {'hooks': []}
            if matcher is not None:
                group['matcher'] = matcher
            groups.append(group)
        existing = [h.get('command') for h in group.setdefault('hooks', [])]
        if hook['command'] not in existing:
            group['hooks'].append(hook)
            added += 1

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f'    {added} hook entries added (existing entries preserved)')
PY

CMUX_BIN="$(command -v cmux 2>/dev/null || true)"
[ -z "$CMUX_BIN" ] && [ -x /Applications/cmux.app/Contents/Resources/bin/cmux ] && CMUX_BIN=/Applications/cmux.app/Contents/Resources/bin/cmux
if [ -n "$CMUX_BIN" ]; then
  echo "==> Validating sidebar"
  CMUX_QUIET=1 "$CMUX_BIN" sidebar validate worktrees || true
fi

cat <<'EOS'

Done! Next steps:

  1. In cmux, RIGHT-CLICK the sidebar toggle button (top-left) and pick "worktrees"
     (or run: cmux sidebar select worktrees)
  2. Restart your Claude Code sessions (or open /hooks once) so the new hooks load.

To go back to the default sidebar, right-click the sidebar toggle button again.
EOS
