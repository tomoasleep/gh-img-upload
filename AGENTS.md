# AGENTS.md - gh-img-upload

このファイルは、このリポジトリで作業する AI エージェント（Claude Code等）向けのガイドラインです。

## プロジェクト概要

`gh-img-upload` は GitHub CLI 拡張機能で、Issue や Pull Request に画像をアップロードし、その URL を返します。コメントは作成・変更されません。

**技術スタック**: Pure Bash script (no build process)

## ビルド・テスト・Lint コマンド

### ビルド

ビルドプロセスは不要（純粋な Bash スクリプト）。

### テスト

現在、自動テストスイートは存在しない。手動テストで動作確認する：

```bash
# ログイン確認
gh img-upload login --headed

# アップロードテスト
gh img-upload upload --issue <issue-number> --image ./test.png
```

### Lint

```bash
# ShellCheck による静的解析（推奨）
shellcheck lib/*.sh bin/* gh-img-upload

# 全ファイル対象
shellcheck lib/session.sh lib/upload.sh bin/gh-img-upload gh-img-upload
```

**注意**: `.shellcheckrc` は存在しないため、デフォルト設定を使用。

## プロジェクト構造

```
gh-img-upload/
├── gh-img-upload          # エントリーポイント（bin/gh-img-upload へのラッパー）
├── bin/
│   └── gh-img-upload      # メイン実行ファイル
├── lib/
│   ├── session.sh         # セッション管理関数
│   └── upload.sh          # 画像アップロード関数
└── SKILL.md               # Agent Skill としての使用方法ドキュメント
```

## コードスタイルガイドライン

### Shebang と strict mode

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `#!/usr/bin/env bash` を使用（`#!/bin/bash` ではなく移植性重視）
- 全スクリプトで `set -euo pipefail` を設定：
  - `-e`: エラー時即座に終了
  - `-u`: 未定義変数の使用でエラー
  - `-o pipefail`: パイプライン内のエラーを検出

### 変数と代入

```bash
# ローカル変数には必ず local を使用
local profile_dir
profile_dir=$(get_profile_dir "$host")

# コマンド置換には $() を使用（バッククォート禁止）
local current_url
current_url=$(playwright-cli eval "window.location.href" 2>/dev/null || echo "")

# 配列の使用
local images=()
while [[ $# -gt 0 && "$1" != "--json" && "$1" != "--headed" && ! "$1" =~ ^-- ]]; do
  images+=("$1")
  shift
done
```

### 条件文

```bash
# [[]] を使用（Bash 拡張、より安全）
if [[ -z "$issue" ]]; then
  echo "Error: --issue is required." >&2
  exit 1
fi

# パターンマッチ
if [[ "$current_url" == *"/login"* ]]; then
  # ...
fi

# 正規表現マッチ
if [[ ! "$1" =~ ^-- ]]; then
  # ...
fi

# 大文字小文字を無視した grep
if echo "$snapshot_output" | grep -qi "Sign in\|Log in"; then
  # ...
fi
```

### エラーハンドリング

```bash
# エラーメッセージは必ず stderr へ
echo "Error: --issue is required." >&2

# 適切な終了コードを使用
exit 1

# クリーンアップ処理（一時ファイル、playwright-cli close）
for tf in "${temp_files[@]}"; do
  rm -f "$tf" 2>/dev/null
done
playwright-cli close 2>&1 | grep -E "Error" || true

# || true でエラーを無視しつつ継続
playwright-cli --profile "$profile_dir" $headed_flag open "$issue_url" 2>&1 | grep -E "Error|opened" || true
```

### 関数定義

```bash
# 関数名は小文字とアンダースコア
upload_images() {
  local repo="$1"
  local issue="$2"
  shift 2
  
  local images=()
  # ...
}

# 値を返す関数は echo で出力
get_host_from_repo() {
  local repo="$1"
  local repo_url
  repo_url="$(gh repo view "$repo" --json url -q .url 2>/dev/null || echo "https://github.com/$repo")"
  echo "$repo_url" | sed -E 's#https?://([^/]+)/.*#\1#'
}
```

### コマンドライン引数処理

```bash
# while ループで引数を処理
local repo=""
local issue=""
local images=()
local json_output=""
local headed=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2;;
    --issue) issue="$2"; shift 2;;
    --image) images+=("$2"); shift 2;;
    --json) json_output="true"; shift;;
    --headed) headed="--headed"; shift;;
    -h|--help) usage; exit 0;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done
```

### 文字列処理

```bash
# パスの絶対パス化
local abs_path
abs_path="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")"

# JSON 出力の構築（シンプルな方法）
local urls_json=""
local first=true
for url in "${upload_urls[@]}"; do
  if [[ "$first" == "true" ]]; then
    urls_json="\"$url\""
    first=false
  else
    urls_json="${urls_json}, \"$url\""
  fi
done

echo "{\"urls\": [$urls_json], \"markdown\": [$markdown_json]}"
```

### 外部コマンドの実行

```bash
# 存在確認
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is required." >&2
  exit 1
fi

# エラー出力の抑制 || true で失敗を許容
repo_url="$(gh repo view "$repo" --json url -q .url 2>/dev/null || echo "https://github.com/$repo")"

# 成功時のみ出力をフィルタリング
playwright-cli close 2>&1 | grep -E "Error" || true
```

### ファイル操作

```bash
# ファイル存在確認
if [[ ! -f "$img" ]]; then
  echo "Error: Image not found: $img" >&2
  exit 1
fi

# 一時ファイルの作成とクリーンアップ
local temp_file="${PWD}/.tmp_upload_${filename}"
cp "$abs_path" "$temp_file" 2>/dev/null
# ... 使用 ...
rm -f "$temp_file" 2>/dev/null

# ディレクトリ作成
mkdir -p "${PROFILE_DIR}/${host}"
```

### ユーザーへのフィードバック

```bash
# 進捗メッセージは stderr へ
echo "Opening browser for login to $host..." >&2
echo "Please login in the browser window, then close it when done." >&2

# 成功メッセージ
echo "Login successful!" >&2
echo "Session saved to: $profile_dir" >&2

# 進捗表示（長時間処理の場合）
if [[ $((waited % 30)) -eq 0 ]]; then
  echo "Still waiting for login... ($waited seconds)" >&2
fi
```

## 命名規則

### 変数名

- **ローカル変数**: 小文字 + アンダースコア（`profile_dir`, `current_url`）
- **定数**: 大文字（`CONFIG_DIR`, `PROFILE_DIR`）
- **配列**: 複数形（`images`, `upload_urls`）
- **フラグ**: ブール値を表す文字列（`json_output="true"`, `headed="--headed"`）

### 関数名

- **動詞 + 名詞**: `session_login`, `upload_images`, `get_host_from_repo`
- **小文字 + アンダースコア**
- **ゲッターは `get_` プレフィックス**

### ファイル名

- **スクリプト**: 小文字 + ハイフン（`gh-img-upload`）
- **ライブラリ**: 小文字 + アンダースコア（`session.sh`, `upload.sh`）

## 依存関係

- `gh CLI` (GitHub CLI)
- `playwright-cli` (`npm install -g @playwright/cli`)

## 重要なパターン

### playwright-cli の使用

```bash
# プロファイル付きで起動
playwright-cli --profile "$profile_dir" --headed open "$url"

# JavaScript 評価
playwright-cli eval "window.location.href"

# スナップショット取得
playwright-cli snapshot

# アップロード
playwright-cli upload "$upload_path"

# クリック
playwright-cli click "$ref"

# キー入力
playwright-cli press "Backspace"

# ブラウザを閉じる
playwright-cli close
```

### エラー時のクリーンアップ

常に以下を確実に実行:
1. 一時ファイルの削除
2. `playwright-cli close` の実行
3. 適切な終了コードで終了

## 関連ドキュメント

- `README.md` - ユーザー向けドキュメント
- `SKILL.md` - Agent Skill としての使用方法（他のエージェントがこのツールを呼び出す場合のガイド）