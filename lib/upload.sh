upload_images() {
  local repo="$1"
  local issue="$2"
  shift 2
  
  local images=()
  while [[ $# -gt 0 && "$1" != "--json" && "$1" != "--headed" && ! "$1" =~ ^-- ]]; do
    images+=("$1")
    shift
  done
  
  local json_output=""
  local headed=""
  local host="github.com"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_output="true"; shift;;
      --headed) headed="--headed"; shift;;
      --host) host="$2"; shift 2;;
      *) shift;;
    esac
  done

  local profile_dir
  profile_dir=$(get_profile_dir "$host")
  
  local profile_data_dir="${profile_dir}/Default"
  if [[ ! -d "$profile_data_dir" ]]; then
    echo "Error: Not logged in. Run 'gh img-upload login --headed' first." >&2
    exit 1
  fi

  local issue_url="https://${host}/${repo}/issues/${issue}"

  local headed_flag=""
  if [[ -n "$headed" ]]; then
    headed_flag="--headed"
  fi

  echo "Opening issue page: $issue_url" >&2
  playwright-cli --profile "$profile_dir" $headed_flag open "$issue_url" 2>&1 | grep -E "Error|opened" || true

  echo "Waiting for page to load..." >&2
  local max_wait=120
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    local current_url
    current_url=$(playwright-cli eval "window.location.href" 2>/dev/null || echo "")
    
    if [[ "$current_url" == *"$host"* && ( "$current_url" == *"/issues/"* || "$current_url" == *"/pull/"* ) ]]; then
      echo "Page loaded." >&2
      break
    fi
    sleep 2
    waited=$((waited + 2))
    if [[ $((waited % 10)) -eq 0 ]]; then
      echo "Still waiting... ($waited seconds)" >&2
    fi
  done

  if [[ $waited -ge $max_wait ]]; then
    echo "Error: Timeout waiting for page to load." >&2
    playwright-cli close 2>&1 | grep -E "Error" || true
    exit 1
  fi

  echo "Checking login status..." >&2
  local snapshot_output
  snapshot_output=$(playwright-cli snapshot 2>&1)
  
  if echo "$snapshot_output" | grep -qi "Sign in\|Log in"; then
    echo "Error: Not logged in to GitHub." >&2
    echo "Run 'gh img-upload login --headed' first." >&2
    playwright-cli close 2>&1 | grep -E "Error" || true
    exit 1
  fi

  local snapshot_file
  snapshot_file=$(echo "$snapshot_output" | grep '\[Snapshot\]' | sed 's/.*(\(.*\))/\1/')

  if [[ -z "$snapshot_file" || ! -f "$snapshot_file" ]]; then
    echo "Error: Failed to get page snapshot." >&2
    playwright-cli close 2>&1 | grep -E "Error" || true
    exit 1
  fi

  local upload_button_ref
  upload_button_ref=$(grep -o 'button "Paste, drop, or click to add files" \[ref=[^]]*\]' "$snapshot_file" 2>/dev/null | head -1 | grep -o 'ref=[^]]*' | cut -d= -f2)

  if [[ -z "$upload_button_ref" ]]; then
    echo "Error: Could not find upload button on the page." >&2
    echo "This could mean:" >&2
    echo "  - You don't have permission to comment on this issue" >&2
    echo "  - The issue doesn't exist" >&2
    echo "  - You are not logged in" >&2
    playwright-cli close 2>&1 | grep -E "Error" || true
    exit 1
  fi

  echo "Found upload button." >&2
  echo "Uploading ${#images[@]} image(s)..." >&2
  local upload_urls=()
  local temp_files=()

  for img in "${images[@]}"; do
    local filename
    filename=$(basename "$img")

    if [[ ! -f "$img" ]]; then
      echo "Error: Image file not found: $img" >&2
      playwright-cli close 2>&1 | grep -E "Error" || true
      exit 1
    fi

    local abs_path
    abs_path="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")"

    local upload_path="$abs_path"
    
    local parent_dir
    parent_dir="$(dirname "$abs_path")"
    
    local in_project=false
    if [[ "$parent_dir" == "$PWD"* ]]; then
      in_project=true
    fi
    
    if [[ "$in_project" != "true" ]]; then
      local temp_file="${PWD}/.tmp_upload_${filename}"
      cp "$abs_path" "$temp_file" 2>/dev/null
      upload_path="$temp_file"
      temp_files+=("$temp_file")
      echo "File copied to project directory for upload: $filename" >&2
    fi
    
    echo "Uploading: $filename" >&2

    snapshot_output=$(playwright-cli snapshot 2>&1)
    snapshot_file=$(echo "$snapshot_output" | grep '\[Snapshot\]' | sed 's/.*(\(.*\))/\1/')
    upload_button_ref=$(grep -o 'button "Paste, drop, or click to add files" \[ref=[^]]*\]' "$snapshot_file" 2>/dev/null | head -1 | grep -o 'ref=[^]]*' | cut -d= -f2)

    if [[ -z "$upload_button_ref" ]]; then
      echo "Error: Upload button not found." >&2
      playwright-cli close 2>&1 | grep -E "Error" || true
      exit 1
    fi

    local click_result
    click_result=$(playwright-cli click "$upload_button_ref" 2>&1)
    if echo "$click_result" | grep -qi "error.*failed\|error.*not found"; then
      echo "Error: Failed to click upload button." >&2
      echo "$click_result" >&2
      playwright-cli close 2>&1 | grep -E "Error" || true
      exit 1
    fi
    sleep 0.5

    local upload_result
    upload_result=$(playwright-cli upload "$upload_path" 2>&1)
    if echo "$upload_result" | grep -qi "Error.*access denied\|Error.*outside allowed"; then
      echo "Error: Failed to upload file." >&2
      echo "$upload_result" >&2
      for tf in "${temp_files[@]}"; do
        rm -f "$tf" 2>/dev/null
      done
      playwright-cli close 2>&1 | grep -E "Error" || true
      exit 1
    fi
    sleep 2

    snapshot_output=$(playwright-cli snapshot 2>&1)
    snapshot_file=$(echo "$snapshot_output" | grep '\[Snapshot\]' | sed 's/.*(\(.*\))/\1/')
    
    local upload_url
    upload_url=$(grep -oE 'src="https://[^"]+/user-attachments/assets/[^"]*"' "$snapshot_file" 2>/dev/null | tail -1 | sed 's/src="//;s/"$//')

    if [[ -z "$upload_url" ]]; then
      echo "Error: Upload completed but URL not found in page." >&2
      echo "The upload may have failed silently." >&2
      for tf in "${temp_files[@]}"; do
        rm -f "$tf" 2>/dev/null
      done
      playwright-cli close 2>&1 | grep -E "Error" || true
      exit 1
    fi

    upload_urls+=("$upload_url")
    echo "Uploaded: $filename -> $upload_url" >&2

    if [[ "$img" != "${images[-1]}" ]]; then
      playwright-cli eval "document.activeElement.select && document.activeElement.select()" >/dev/null 2>&1
      playwright-cli press "Backspace" >/dev/null 2>&1
      sleep 0.5
    fi
  done

  playwright-cli close 2>&1 | grep -E "Error" || true

  for tf in "${temp_files[@]}"; do
    rm -f "$tf" 2>/dev/null
  done

  if [[ -n "$json_output" ]]; then
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

    local markdown_json=""
    first=true
    local idx=0
    for url in "${upload_urls[@]}"; do
      local img_filename
      img_filename=$(basename "${images[$idx]}")
      if [[ "$first" == "true" ]]; then
        markdown_json="\"![${img_filename}](${url})\""
        first=false
      else
        markdown_json="${markdown_json}, \"![${img_filename}](${url})\""
      fi
      idx=$((idx + 1))
    done

    echo "{\"urls\": [$urls_json], \"markdown\": [$markdown_json]}"
  else
    for url in "${upload_urls[@]}"; do
      echo "$url"
    done
  fi
}