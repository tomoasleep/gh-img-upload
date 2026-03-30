# gh-img-upload

A GitHub CLI extension to upload images and return URLs without creating or modifying comments.

## Requirements

- [gh CLI](https://cli.github.com/) (authenticated)
- [playwright-cli](https://github.com/microsoft/playwright-cli) (for browser automation)

## Install

```bash
gh extension install tomoasleep/gh-img-upload
```

Or manually:

```bash
git clone https://github.com/tomoasleep/gh-img-upload.git
cd gh-img-upload
gh extension install .
```

Install playwright-cli:

```bash
npm install -g @playwright/cli
```

### Install Agent Skill

```bash
npx skills add tomoasleep/gh-img-upload
```

## Usage

### Login

First, create a browser session for GitHub. The `--headed` flag is required to open a visible browser window for authentication:

```bash
# Login to GitHub.com
gh img-upload login --headed

# Login to GitHub Enterprise
gh img-upload login --host github.mycompany.com --headed
```

Login in the browser window, then close it when done. The session will be saved for future uploads.

### Upload Images

```bash
# Upload image to an issue (uses current repo)
gh img-upload upload --issue 123 --image ./screenshot.png

# Upload to a specific repository
gh img-upload upload --repo owner/repo --issue 456 --image ./screenshot.png

# Upload multiple images
gh img-upload upload --issue 123 --image ./before.png --image ./after.png

# JSON output
gh img-upload upload --issue 123 --image ./test.png --json

# Debug mode (show browser window)
gh img-upload upload --issue 123 --image ./test.png --headed
```

### Status

```bash
# Show login status for github.com
gh img-upload status

# Show login status for GitHub Enterprise
gh img-upload status --host github.mycompany.com

# JSON output
gh img-upload status --json
```

### Output

Default output (one URL per line):

```
https://github.com/user-attachments/assets/xxx
```

JSON output (`--json`):

```json
{
  "urls": ["https://github.com/user-attachments/assets/xxx"],
  "markdown": ["![screenshot.png](https://github.com/user-attachments/assets/xxx)"]
}
```

## Options

### `gh img-upload login`

| Option | Description |
|--------|-------------|
| `--host <host>` | GitHub host (default: `github.com`) |
| `--headed` | **Required** - Run browser in headed mode (visible) |

### `gh img-upload upload`

| Option | Description |
|--------|-------------|
| `--repo <owner/repo>` | Target repository (default: current repo) |
| `--issue <number>` | Issue or PR number (required) |
| `--image <path>` | Image file path to upload (required, can be repeated) |
| `--json` | Output as JSON format |
| `--headed` | Run browser in headed mode (visible) - useful for debugging |

### `gh img-upload status`

| Option | Description |
|--------|-------------|
| `--host <host>` | GitHub host (default: `github.com`) |
| `--json` | Output as JSON format |

## Notes

- Issue number is required - uploads need an actual Issue/PR page
- Comments are not modified - only URLs are returned
- Sessions are persisted in `~/.config/gh-img-upload/profiles/<host>/`
- If login session is expired, you'll need to run `gh img-upload login --headed` again
- You can check current session state with `gh img-upload status`

## Troubleshooting

- `Error: Not logged in to GitHub.`
  - Your persisted browser session is not valid.
  - Run `gh img-upload login --headed` and complete login in the opened browser.
- `Error: Issue/PR page is not accessible (404).`
  - The target issue/PR or repository is not visible to your account.
  - Check repository access permissions, organization SSO, and issue number.

## License

MIT
