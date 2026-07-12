# cmux-worktree-map

[![CI](https://github.com/oguressive/cmux-worktree-map/actions/workflows/ci.yml/badge.svg)](https://github.com/oguressive/cmux-worktree-map/actions/workflows/ci.yml)

[cmux](https://cmux.com) 上で動く各 [Claude Code](https://claude.com/claude-code) セッションが「**どのworktreeで・どんな状態か**」をリアルタイムに一覧表示するサイドバーです。

worktreeでの並行開発でタブが増えてくると、「どのタブで何をしていたか」が分からなくなりがちです。このサイドバーがあれば**全セッションの居場所とgit状態**を一目で把握でき、クリックでそのタブへ直接遷移できます。

<img src="docs/screenshot.png" width="360" alt="Worktree Mapサイドバー: worktreeセッションの未コミット/未pushマークとneeds inputバッジ">

```
Tab 1
  🌱 my-repo › fix-payment-bug  🟠 ⇡   ← リポジトリ › worktree・未コミット・未push
     ✳ Fix payment validation bug      ← セッション名
     fix-payment-bug                   ← チェックアウト中ブランチ

Tab 2  🔴 needs input                  ← Claudeがあなたのアクション待ちでブロック中
     my-repo                           ← メインリポジトリのセッション（🌱なし）
     ✳ Investigating flaky tests
     master
```

マークは常に**そのセッションが今いるディレクトリ**の状態を表します。worktree（🌱）にいる行は**そのworktree自身**の未コミット/未push状態、メインリポジトリにいる行はメインリポジトリの状態です。

## 特徴

- **1セッション=1行** — worktree（またはディレクトリ）名・セッションタイトル・チェックアウト中ブランチ
- **🌱 worktreeインジケータ** — worktreeで隔離されたセッションか、本体チェックアウトかが一目で分かる
- **🟠 未コミット / ⇡ 未push** — 各セッションの*実際の*作業ディレクトリに対して本物の`git`で計測
- **`needs input` バッジ** — Claudeが許可プロンプトや質問で*あなた待ちでブロックしている*時だけ点灯（ただのidleでは点かない）
- **クリックで遷移** — タブ選択＋該当ペインへフォーカス
- **イベント駆動・常駐なし** — どこかのセッションが動くたびに全タブ更新。ポーリングプロセスなし

## 仕組み

Claude Codeのworktree移動（`EnterWorktree`）は`claude`プロセスの内部で起きるため、シェル—つまりcmux—は本当の作業ディレクトリを知りません。このギャップを3つの小さなhookで埋めます:

| コンポーネント | 仕組み |
|---|---|
| `cmux-osc7-cwd.sh` | セッションの実cwdを**OSC 7**エスケープで自分のttyへ通知し、cmuxのタブ単位directory/branch追跡を正確にする |
| `cmux-unpushed-sync.sh` | セッションのイベントを契機に**全タブ**をスイープ: ディレクトリごとに`git status`/`git rev-list --count HEAD --not --remotes`を実行し、結果をworkspaceの*description*フィールド経由で配信 |
| `cmux-needs-input.sh` | セッションのフェーズ（実行中/idle）を記録し、「ユーザー待ちブロック」をworkspaceの*color*フィールド経由で配信。idle通知は無視 |
| `sidebars/worktrees.swift` | cmuxの[カスタムサイドバー](https://cmux.com/docs/custom-sidebars)として全部をライブ描画 |

workspaceの**description**と**color**を信号チャネルとして使っています（cmuxは現状、カスタムメタデータをカスタムサイドバーに公開していないため）。手動設定されたdescription/colorは検知して保護します。

## 動作要件

- macOS
- [cmux](https://cmux.com)（custom sidebars beta有効、デフォルトON）
- [Claude Code](https://claude.com/claude-code)
- `python3`（macOS同梱）

## インストール

```sh
git clone https://github.com/oguressive/cmux-worktree-map.git
cd cmux-worktree-map
./install.sh
```

その後:

1. cmuxで**サイドバー切り替えボタン（左上）を右クリック**し、**worktrees**を選択
2. Claude Codeセッションを再起動（または`/hooks`を一度開く）してhookを読み込ませる

インストーラは`~/.claude/settings.json`へ既存hookを壊さずマージします（タイムスタンプ付きバックアップを作成、再実行しても重複しません）。ファイルを配置するだけでcmuxとは通信しないため、**どのターミナルから実行しても同じ**です。

サイドバーの表示がおかしい場合は、**cmux内のターミナル**で `cmux sidebar validate worktrees` を実行すると診断が見られます（cmuxのコントロールソケットはcmux内のプロセスからの接続しか受け付けない仕様のため、cmux外からは実行できません）。

## マークの意味

| マーク | 意味 |
|---|---|
| 🌱 | セッションがgit worktree（`.claude/worktrees/…`）内にいる |
| 🟠 | そのセッションのディレクトリに未コミット変更あり |
| ⇡ | どのリモートにも無いコミット（未push）あり |
| 🔴 `needs input` | Claudeがあなたのアクション待ちでブロック中（許可/質問） |
| 🔔 n | そのタブの未読cmux通知 |

## 更新タイミング

マークは、どこかのセッションがイベント（プロンプト送信・ファイル編集・`git`実行・ターン終了・セッション開始）を起こすたびに更新されます。エディタ等Claude外での変更は、次にどこかのセッションが動いた時に反映されます。バックグラウンドのポーリングはありません。

## セキュリティ

監査しやすさを重視した作りにしています:

- **依存ゼロ** — 素のBashとPython 3標準ライブラリのみで動作し、パッケージのダウンロードやインストールは一切行いません
- **ネットワークアクセスなし** — hookもサイドバーも通信を行いません。状態（worktreeパス・git状態）はあなたのマシン内に留まり、cmuxのローカルなworkspaceフィールドにのみ書き込まれます
- **小さく読める実装** — シェルスクリプト5本とサイドバー1ファイルのみ。システムに触れる処理はすべて平文で確認できます
- **書き込み先は明示的** — `~/.config/cmux/sidebars/worktrees.swift`、`~/.claude/hooks/cmux-*.sh`、`~/.claude/settings.json`（既存設定を壊さずマージ・タイムスタンプ付きバックアップを事前作成）、および`~/.claude/`配下の小さな状態ファイル2つだけです
- **継続的に検証** — push毎に[ShellCheck](https://www.shellcheck.net/)（静的解析・指摘ゼロ）と[Gitleaks](https://github.com/gitleaks/gitleaks)（全履歴のシークレットスキャン）を[CI](https://github.com/oguressive/cmux-worktree-map/actions/workflows/ci.yml)で実行しています

## アンインストール

```sh
./uninstall.sh
```

## ライセンス

[MIT](LICENSE)
