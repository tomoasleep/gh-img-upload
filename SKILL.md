---
name: gh-img-upload
description: Upload images to GitHub Issues/PRs and get URLs without creating comments. Use when: sharing test screenshots to GitHub Issues/PRs, creating bug reports with images, UI review support, uploading images from automated scripts or CI/CD pipelines, posting screenshots from Playwright/E2E tests. GitHub CLI extension for automated image uploads.
---

GitHub Issue/PR に画像をアップロードし、URL を返す gh CLI の拡張機能。

## 概要

`gh-img-upload` は GitHub CLI 拡張機能で、Issue や Pull Request に画像をアップロードし、その URL を返します。
コメントは作成・変更されず、純粋にアップロードされた画像の URL のみが返されます。

## 使用シーン

### 推奨される使用ケース

Agent が以下のタスクを実行する際に使用:

1. **テスト結果の報告**: 自動テストでキャプチャしたスクリーンショットを Issue/PR に共有
2. **バグレポートの作成**: エラー画面のスクリーンショットを GitHub にアップロード
3. **UI レビューのサポート**: 変更前後のスクリーンショット比較を PR に添付
4. **Agent による画像アップロード**: CLI/スクリプトから GitHub へ画像をアップロード
5. **CI/CD パイプライン**: ビルドやテスト結果の画像を GitHub にアップロード

### Agent Skill として活用例

- Playwright 等の E2E テストで取得したスクリーンショットを GitHub Issue に報告
- デバッグログとして画面キャプチャを保存・共有
- ドキュメント作成時にサンプル画像をアップロード
- 自動化スクリプトからバグレポート用画像を投稿

### 適さないケース

- コメントを作成したい場合 → `gh issue comment` や `gh pr comment` を使用
- 公開 URL が必要な場合（GitHub user-attachments は認証が必要な場合がある）
- Issue/PR を指定せずに単独でアップロードしたい場合

## 前提条件

### 必須ツール

- `gh CLI` (認証済み)
- `playwright-cli` (`npm install -g @playwright/cli`)

### セットアップ

```bash
# 拡張機能のインストール
gh extension install tomoasleep/gh-img-upload

# playwright-cli のインストール
npm install -g @playwright/cli

# GitHub へのログイン（初回のみ、--headed が必須）
gh img-upload login --headed

# GitHub Enterprise の場合
gh img-upload login --host github.mycompany.com --headed
```

## 使い方

### 基本的なアップロード

```bash
# Issue に画像をアップロード
gh img-upload upload --issue 123 --image ./screenshot.png

# 別リポジトリを指定
gh img-upload upload --repo owner/repo --issue 456 --image ./image.png
```

### 複数画像のアップロード

```bash
gh img-upload upload --issue 123 --image ./before.png --image ./after.png
```

### JSON 形式での出力

```bash
gh img-upload upload --issue 123 --image ./test.png --json
# {"urls": ["https://github.com/user-attachments/assets/xxx"], "markdown": ["![test.png](https://github.com/user-attachments/assets/xxx)"]}
```

### デバッグモード

```bash
# ブラウザを表示して動作確認
gh img-upload upload --issue 123 --image ./test.png --headed
```

## 出力形式

### デフォルト出力

```
https://github.com/user-attachments/assets/xxx
```

### JSON 出力 (`--json`)

```json
{
  "urls": ["https://github.com/user-attachments/assets/xxx"],
  "markdown": ["![screenshot.png](https://github.com/user-attachments/assets/xxx)"]
}
```

## セッション管理

- セッションは `~/.config/gh-img-upload/profiles/<host>/` に保存
- セッション期限切れ時は再度 `gh img-upload login --headed` を実行

## 注意事項

### 必要な権限

- Issue/PR へのコメント権限

### 制約

- Issue/PR 番号が必須（アップロードには実際の Issue/PR ページが必要）
- コメントは作成されない（URL のみ返却）
- GitHub Enterprise にも対応

## トラブルシューティング

### ログインエラー

```bash
Error: Not logged in. Run 'gh img-upload login --headed' first.
```

→ `gh img-upload login --headed` を実行してブラウザでログイン

### 権限エラー

```bash
Error: Could not find upload button on the page.
```

→ 以下の可能性:
  - Issue/PR へのコメント権限がない
  - Issue/PR が存在しない
  - ログインしていない

## 関連リンク

- [GitHub CLI](https://cli.github.com/)
- [playwright-cli](https://github.com/microsoft/playwright-cli)
- [gh-img-upload Repository](https://github.com/tomoasleep/gh-img-upload)
