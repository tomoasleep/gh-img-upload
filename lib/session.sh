CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gh-img-upload"
PROFILE_DIR="${CONFIG_DIR}/profiles"

get_host_from_repo() {
  local repo="$1"
  local repo_url
  repo_url="$(gh repo view "$repo" --json url -q .url 2>/dev/null || echo "https://github.com/$repo")"
  echo "$repo_url" | sed -E 's#https?://([^/]+)/.*#\1#'
}

get_profile_dir() {
  local host="$1"
  mkdir -p "${PROFILE_DIR}/${host}"
  echo "${PROFILE_DIR}/${host}"
}

session_login() {
  local host="$1"
  local headed="$2"
  local profile_dir
  profile_dir=$(get_profile_dir "$host")

  if [[ -z "$headed" ]]; then
    echo "Error: --headed flag is required for login." >&2
    echo "  gh img-upload login --headed" >&2
    exit 1
  fi

  local login_url
  login_url="https://${host}/login"

  echo "Opening browser for login to $host..." >&2
  echo "Please login in the browser window, then close it when done." >&2

  playwright-cli --profile "$profile_dir" --headed open "$login_url" >/dev/null 2>&1

  local current_url
  current_url=$(playwright-cli eval "window.location.href" 2>/dev/null || echo "")
  
  echo "Waiting for login..." >&2

  local max_wait=300
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    sleep 3
    waited=$((waited + 3))
    current_url=$(playwright-cli eval "window.location.href" 2>/dev/null || echo "")
    
    if [[ "$current_url" != *"/login"* ]] && [[ "$current_url" != *"/sessions"* ]] && [[ "$current_url" != *"/two-factor"* ]]; then
      local user_login
      user_login=$(playwright-cli eval "document.querySelector('meta[name=\"user-login\"]')?.content || ''" 2>/dev/null || echo "")

      local snapshot_content
      snapshot_content=$(playwright-cli snapshot 2>&1 || echo "")
      if [[ -n "$user_login" ]] && ! echo "$snapshot_content" | grep -qi 'Sign in to GitHub\|Username or email address\|button "Sign in"'; then
        echo "Login successful!" >&2
        playwright-cli close >/dev/null 2>&1
        echo "Session saved to: $profile_dir" >&2
        echo "Login complete!" >&2
        return 0
      fi
    fi

    if [[ $((waited % 30)) -eq 0 ]]; then
      echo "Still waiting for login... ($waited seconds)" >&2
    fi
  done

  echo "Error: Login timeout. Could not confirm a persisted login session." >&2
  echo "Please run 'gh img-upload login --headed' and complete login until your account is shown." >&2
  playwright-cli close >/dev/null 2>&1
  exit 1
}

session_status() {
  local host="$1"
  local json_output="$2"
  local profile_dir
  profile_dir=$(get_profile_dir "$host")

  local profile_data_dir="${profile_dir}/Default"
  local logged_in="false"
  local user_login=""

  if [[ -d "$profile_data_dir" ]]; then
    local home_url
    home_url="https://${host}/"

    playwright-cli --profile "$profile_dir" open "$home_url" >/dev/null 2>&1 || true

    local raw_user_login
    raw_user_login=$(playwright-cli eval "document.querySelector('meta[name=\"user-login\"]')?.content || ''" 2>/dev/null || echo "")
    user_login=$(echo "$raw_user_login" | sed -n '/^### /d;/^```/d;/^await page\.evaluate/d;/^[[:space:]]*$/d;s/^"//;s/"$//;p' | sed -n '1p')

    local snapshot_output
    snapshot_output=$(playwright-cli snapshot 2>&1 || echo "")

    if [[ -n "$user_login" ]] && ! echo "$snapshot_output" | grep -qi 'Sign in to GitHub\|Username or email address\|button "Sign in"'; then
      logged_in="true"
    fi

    playwright-cli close >/dev/null 2>&1 || true
  fi

  if [[ -n "$json_output" ]]; then
    echo "{\"host\":\"$host\",\"logged_in\":$logged_in,\"user\":\"$user_login\"}"
  else
    if [[ "$logged_in" == "true" ]]; then
      echo "Logged in as: $user_login (host: $host)"
    else
      echo "Not logged in (host: $host)"
    fi
  fi

  if [[ "$logged_in" == "true" ]]; then
    return 0
  fi

  return 1
}
