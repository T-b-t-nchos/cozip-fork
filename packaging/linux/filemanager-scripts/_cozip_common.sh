# Shared helper sourced by CoZip file-manager scripts.
#
# Supports Nautilus (GNOME), Nemo (Cinnamon) and Caja (MATE). Each of those
# file managers exports the selection through its own *_SCRIPT_SELECTED_FILE_PATHS
# environment variable (newline separated, absolute paths).
#
# The installer rewrites @COZIP_DESKTOP@ to the absolute cozip_desktop path.

cozip_desktop_bin() {
  printf '%s' "@COZIP_DESKTOP@"
}

# Collects the selected paths from whichever file manager invoked the script and
# prints them, one per line. Empty lines are dropped.
cozip_selected_paths() {
  local raw=""
  if [[ -n "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}" ]]; then
    raw="${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"
  elif [[ -n "${NEMO_SCRIPT_SELECTED_FILE_PATHS:-}" ]]; then
    raw="${NEMO_SCRIPT_SELECTED_FILE_PATHS}"
  elif [[ -n "${CAJA_SCRIPT_SELECTED_FILE_PATHS:-}" ]]; then
    raw="${CAJA_SCRIPT_SELECTED_FILE_PATHS}"
  fi

  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done <<< "$raw"
}

# Reads selected paths into the array named by $1.
cozip_read_selection_into() {
  local -n _out="$1"
  _out=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && _out+=("$line")
  done < <(cozip_selected_paths)
}
