# cmux-worktree-map

A live **worktree map sidebar** for [cmux](https://cmux.com) + [Claude Code](https://claude.com/claude-code).

Running many Claude Code sessions across git worktrees in cmux tabs? This sidebar shows, at a glance, **which worktree every session is in and what state its work is in** — and jumps to the right tab on click.

```
Tab 2
  🌱 my-repo › fix-payment-bug   🟠 ⇡      ← worktree, uncommitted, unpushed
     ✳ Fix payment validation bug          ← session name
     fix-payment-bug                       ← checked-out branch

  my-repo                                  ← session on the main checkout
     ✳ Investigating flaky tests
     master
```

## Features

- **One row per Claude Code session** — worktree (or directory) name, session title, and checked-out branch
- **🌱 worktree indicator** — instantly see which sessions run in an isolated worktree vs. the main checkout
- **🟠 uncommitted changes / ⇡ unpushed commits** — measured with real `git` against each session's *actual* working directory
- **`needs input` badge** — lights up only when Claude is *blocked* on you (permission prompt / question mid-turn), not when a session is merely idle
- **Click to jump** — selects the tab and focuses the exact pane
- **Event-driven, no daemons** — state updates whenever any session does something; no polling processes

## Why hooks? (How it works)

Claude Code switches into worktrees *inside* the `claude` process (`EnterWorktree`), so the shell — and therefore cmux — never learns the real working directory. This project closes that gap with three small Claude Code hooks:

| Component | Mechanism |
|---|---|
| `cmux-osc7-cwd.sh` | Reports the session's real cwd to its tty via an **OSC 7** escape, so cmux's per-tab directory/branch tracking becomes accurate |
| `cmux-unpushed-sync.sh` | On any session event, sweeps **all** tabs: runs `git status` / `git rev-list --count HEAD --not --remotes` per directory and publishes the result through the workspace *description* field |
| `cmux-needs-input.sh` | Tracks each session's phase (running/idle) and publishes "blocked on user" through the workspace *color* field — idle "waiting for your input" notifications are ignored |
| `sidebars/worktrees.swift` | A cmux [custom sidebar](https://cmux.com/docs/custom-sidebars) that renders it all, live |

The workspace **description** and **color** fields are used as signal channels (cmux does not yet expose custom metadata to custom sidebars). Manually-set descriptions/colors are detected and left untouched.

## Requirements

- macOS
- [cmux](https://cmux.com) with the custom-sidebars beta enabled (on by default)
- [Claude Code](https://claude.com/claude-code)
- `python3` (ships with macOS)

## Install

```sh
git clone https://github.com/oguressive/cmux-worktree-map.git
cd cmux-worktree-map
./install.sh
```

Then:

1. In cmux, **right-click the sidebar toggle button** (top-left) and pick **worktrees**
2. Restart your Claude Code sessions (or open `/hooks` once) so the hooks load

The installer merges hook registrations into `~/.claude/settings.json` non-destructively (a timestamped backup is written first) and is idempotent.

## Legend

| Mark | Meaning |
|---|---|
| 🌱 | Session is inside a git worktree (`.claude/worktrees/…`) |
| 🟠 | Uncommitted changes in that session's directory |
| ⇡ | Commits not pushed to any remote |
| 🔴 `needs input` | Claude is blocked waiting for your action (permission / question) |
| 🔔 n | Unread cmux notifications for the tab |

## Freshness model

Marks update when any session fires an event (prompt submitted, file edited, `git` command run, turn ended, session started). Edits made outside Claude Code (e.g. in your editor) are picked up on the next event from any session. There is no background polling.

## Uninstall

```sh
./uninstall.sh
```

## License

[MIT](LICENSE)
