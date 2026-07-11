# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- CI: ShellCheck and Gitleaks run on every push / pull request
- Security section in README (dependency-free, no network access, explicit write targets)

## [0.1.0] - 2026-07-11

### Added

- Custom cmux sidebar (`worktrees.swift`) showing one row per Claude Code session:
  repository › worktree name, session title, and checked-out branch
- 🌱 worktree indicator for sessions running inside a git worktree
- 🟠 uncommitted / ⇡ unpushed marks measured with real `git` against each
  session's actual working directory
- `needs input` badge that lights up only when Claude is blocked on the user
  (permission prompt / question mid-turn), ignoring idle notifications
- Click-to-jump: selecting a row focuses the tab and the exact pane
- `cmux-osc7-cwd.sh` hook: reports each session's real cwd to its tty via OSC 7
- `cmux-unpushed-sync.sh` hook: event-driven sweep publishing git state for all
  tabs through the workspace description channel
- `cmux-needs-input.sh` hook: phase-aware needs-input signal through the
  workspace color channel
- Idempotent `install.sh` (non-destructive settings.json merge with backups)
  and `uninstall.sh`
- README (English / Japanese) with screenshot

[Unreleased]: https://github.com/oguressive/cmux-worktree-map/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/oguressive/cmux-worktree-map/releases/tag/v0.1.0
