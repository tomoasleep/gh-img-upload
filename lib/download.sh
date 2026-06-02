download_image() {
  local url="$1"
  shift

  local output=""
  local json_output=""
  local headed=""
  local host="github.com"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output="$2"; shift 2;;
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
    echo "Error: Not logged in. Run 'gh img-upload login --host ${host} --headed' first." >&2
    exit 1
  fi

  local headed_flag=""
  if [[ -n "$headed" ]]; then
    headed_flag="--headed"
  fi

  local filename
  filename="$(basename "${url%%\?*}")"
  if [[ -z "$filename" ]] || [[ "$filename" == "/" ]]; then
    filename="downloaded-image"
  fi

  local output_path=""
  if [[ -z "$output" ]]; then
    output_path="${PWD}/${filename}"
  elif [[ -d "$output" ]]; then
    output_path="$(cd "$output" && pwd)/${filename}"
  else
    local output_dir
    output_dir="$(dirname "$output")"
    mkdir -p "$output_dir"
    output_path="$(cd "$output_dir" && pwd)/$(basename "$output")"
  fi

  echo "Opening image URL: $url" >&2
  playwright-cli --profile "$profile_dir" $headed_flag open "$url" >/dev/null 2>&1 || true

  local current_url
  current_url=$(playwright-cli eval "window.location.href" 2>/dev/null || echo "")
  if [[ "$current_url" == *"/login"* ]] || [[ "$current_url" == *"/sessions"* ]] || [[ "$current_url" == *"/two-factor"* ]]; then
    echo "Error: Not logged in to GitHub for host $host." >&2
    echo "Run 'gh img-upload login --host ${host} --headed' first." >&2
    playwright-cli close >/dev/null 2>&1 || true
    exit 1
  fi

  local fetch_output
  fetch_output=$(playwright-cli eval "(async () => {
    try {
      const target = window.location.href;
      const response = await fetch(target, { credentials: 'include' });
      if (!response.ok) {
        return '__DL_ERROR__HTTP_' + response.status;
      }
      const contentType = response.headers.get('content-type') || '';
      if (!contentType.toLowerCase().includes('image/')) {
        return '__DL_ERROR__NOT_IMAGE_' + contentType;
      }
      const bytes = new Uint8Array(await response.arrayBuffer());
      let binary = '';
      const chunkSize = 0x8000;
      for (let i = 0; i < bytes.length; i += chunkSize) {
        const chunk = bytes.subarray(i, i + chunkSize);
        binary += String.fromCharCode.apply(null, chunk);
      }
      return '__DL_BASE64__' + btoa(binary);
    } catch (error) {
      return '__DL_ERROR__EXCEPTION_' + String(error && error.message ? error.message : error);
    }
  })()" 2>/dev/null || true)

  playwright-cli close >/dev/null 2>&1 || true

  local data_line
  data_line=$(echo "$fetch_output" | sed -n 's/^"__DL_BASE64__\(.*\)"$/\1/p' | sed -n '1p')
  if [[ -z "$data_line" ]]; then
    data_line=$(echo "$fetch_output" | sed -n 's/^__DL_BASE64__\(.*\)$/\1/p' | sed -n '1p')
  fi

  if [[ -z "$data_line" ]]; then
    local error_line
    error_line=$(echo "$fetch_output" | grep '__DL_ERROR__' | sed -n '1p')
    if [[ "$error_line" == *"__DL_ERROR__HTTP_401"* ]] || [[ "$error_line" == *"__DL_ERROR__HTTP_403"* ]]; then
      echo "Error: Access denied while downloading image. Check login/session for $host." >&2
    elif [[ "$error_line" == *"__DL_ERROR__HTTP_404"* ]]; then
      echo "Error: Image not found (404)." >&2
    elif [[ "$error_line" == *"__DL_ERROR__NOT_IMAGE_"* ]]; then
      echo "Error: Target URL did not return an image." >&2
    else
      echo "Error: Failed to download image via browser session." >&2
    fi
    exit 1
  fi

  if ! printf '%s' "$data_line" | base64 -d >"$output_path" 2>/dev/null; then
    if ! printf '%s' "$data_line" | base64 -D >"$output_path" 2>/dev/null; then
      echo "Error: Failed to decode image data." >&2
      rm -f "$output_path" 2>/dev/null
      exit 1
    fi
  fi

  if [[ -n "$json_output" ]]; then
    echo "{\"url\":\"$url\",\"path\":\"$output_path\"}"
  else
    echo "$output_path"
  fi
}
