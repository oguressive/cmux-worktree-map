#!/bin/bash
# cmux-worktree-map uninstaller
# Removes the sidebar, hook scripts, hook registrations, and state files.
set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "==> Removing hook registrations from $SETTINGS"
if [ -f "$SETTINGS" ]; then
  python3 - "$SETTINGS" <<'PY'
import json, shutil, sys, time

settings_path = sys.argv[1]
shutil.copy(settings_path, settings_path + f'.bak.{int(time.time())}')
with open(settings_path) as f:
    settings = json.load(f)

MARKERS = ('cmux-osc7-cwd.sh', 'cmux-needs-input.sh', 'cmux-unpushed-sync.sh')
removed = 0
hooks = settings.get('hooks', {})
for event in list(hooks.keys()):
    groups = hooks[event]
    for g in groups:
        before = len(g.get('hooks', []))
        g['hooks'] = [h for h in g.get('hooks', [])
                      if not any(m in h.get('command', '') for m in MARKERS)]
        removed += before - len(g['hooks'])
    hooks[event] = [g for g in groups if g.get('hooks')]
    if not hooks[event]:
        del hooks[event]

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f'    {removed} hook entries removed')
PY
fi

echo "==> Removing files"
rm -f "$HOME/.config/cmux/sidebars/worktrees.swift"
rm -f "$HOOKS_DIR/cmux-osc7-cwd.sh" "$HOOKS_DIR/cmux-needs-input.sh" "$HOOKS_DIR/cmux-unpushed-sync.sh"
rm -f "$HOME/.claude/cmux-git-registry.json" "$HOME/.claude/cmux-needs-input-state.json"

echo "Done. If the sidebar is still selected, right-click the sidebar toggle button in cmux and pick the default."
