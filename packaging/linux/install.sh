#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
SERVICEMENU_DIR="${HOME}/.local/share/kio/servicemenus"
MIME_DIR="${HOME}/.local/share/mime/packages"
DATA_DIR="${HOME}/.local/share/cozip"
ICON_DIR="${DATA_DIR}/icons"
COZIP_DESKTOP_BIN="${BIN_DIR}/cozip_desktop"
COZIP_COMP_ICON="${ICON_DIR}/comp.ico"
COZIP_DECOMP_ICON="${ICON_DIR}/decomp.ico"
# GNOME (Nautilus) / Cinnamon (Nemo) / MATE (Caja) right-click "Scripts" support.
COZIP_FM_COMMON="${DATA_DIR}/filemanager-common.sh"
NAUTILUS_SCRIPT_DIR="${HOME}/.local/share/nautilus/scripts"
NEMO_SCRIPT_DIR="${HOME}/.local/share/nemo/scripts"
CAJA_SCRIPT_DIR="${HOME}/.config/caja/scripts"
FM_SCRIPT_NAMES=(
  "CoZip Compress to ZIP"
  "CoZip Compress to CoZip"
  "CoZip Compress (options)"
  "CoZip Extract Here"
  "CoZip Extract (options)"
)

build=1
if [[ "${1:-}" == "--no-build" ]]; then
  build=0
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--no-build]" >&2
  exit 2
fi

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&|]/\\&/g'
}

install_desktop_template() {
  local src="$1"
  local dst="$2"
  local escaped_bin
  local escaped_comp_icon
  local escaped_decomp_icon
  escaped_bin="$(escape_sed_replacement "$COZIP_DESKTOP_BIN")"
  escaped_comp_icon="$(escape_sed_replacement "$COZIP_COMP_ICON")"
  escaped_decomp_icon="$(escape_sed_replacement "$COZIP_DECOMP_ICON")"
  mkdir -p "$(dirname "$dst")"
  sed \
    -e "s|@COZIP_DESKTOP@|${escaped_bin}|g" \
    -e "s|@COZIP_COMP_ICON@|${escaped_comp_icon}|g" \
    -e "s|@COZIP_DECOMP_ICON@|${escaped_decomp_icon}|g" \
    "$src" > "$dst"
  chmod 0644 "$dst"
}

install_filemanager_common() {
  local escaped_bin
  escaped_bin="$(escape_sed_replacement "$COZIP_DESKTOP_BIN")"
  mkdir -p "$(dirname "$COZIP_FM_COMMON")"
  sed \
    -e "s|@COZIP_DESKTOP@|${escaped_bin}|g" \
    "$SCRIPT_DIR/filemanager-scripts/_cozip_common.sh" > "$COZIP_FM_COMMON"
  chmod 0644 "$COZIP_FM_COMMON"
}

install_filemanager_scripts_into() {
  local dst_dir="$1"
  local escaped_common
  escaped_common="$(escape_sed_replacement "$COZIP_FM_COMMON")"
  mkdir -p "$dst_dir"
  local name
  for name in "${FM_SCRIPT_NAMES[@]}"; do
    sed \
      -e "s|@COZIP_FM_COMMON@|${escaped_common}|g" \
      "$SCRIPT_DIR/filemanager-scripts/${name}" > "${dst_dir}/${name}"
    chmod 0755 "${dst_dir}/${name}"
  done
}

refresh_desktop_caches() {
  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$APP_DIR" 2>/dev/null || true
  command -v update-mime-database >/dev/null 2>&1 \
    && update-mime-database "${HOME}/.local/share/mime" 2>/dev/null || true
  command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true
  command -v kbuildsycoca5 >/dev/null 2>&1 && kbuildsycoca5 >/dev/null 2>&1 || true
}

if [[ "$build" == "1" ]]; then
  echo "==> Building cozip_desktop (release)..."
  cargo build -p cozip_desktop --release --quiet --manifest-path "$REPO_ROOT/Cargo.toml"
fi

echo "==> Installing binary..."
mkdir -p "$BIN_DIR"
install -m 0755 "$REPO_ROOT/target/release/cozip_desktop" "$COZIP_DESKTOP_BIN"

echo "==> Installing icons..."
mkdir -p "$ICON_DIR"
install -m 0644 "$REPO_ROOT/src/cozip_desktop/icons/comp.ico" "$COZIP_COMP_ICON"
install -m 0644 "$REPO_ROOT/src/cozip_desktop/icons/decomp.ico" "$COZIP_DECOMP_ICON"

echo "==> Installing desktop entry..."
install_desktop_template "$SCRIPT_DIR/cozip.desktop" "$APP_DIR/cozip.desktop"

echo "==> Registering MIME type..."
mkdir -p "$MIME_DIR"
install -m 0644 "$SCRIPT_DIR/mime/application-x-cozip.xml" "$MIME_DIR/application-x-cozip.xml"

echo "==> Installing Dolphin service menus..."
mkdir -p "$SERVICEMENU_DIR"
rm -f \
  "$SERVICEMENU_DIR/cozip-compress.desktop" \
  "$SERVICEMENU_DIR/cozip-extract.desktop"
install_desktop_template "$SCRIPT_DIR/cozip-compress-zip-servicemenu.desktop" "$SERVICEMENU_DIR/cozip-10-compress-zip.desktop"
install_desktop_template "$SCRIPT_DIR/cozip-compress-cozip-servicemenu.desktop" "$SERVICEMENU_DIR/cozip-20-compress-cozip.desktop"
install_desktop_template "$SCRIPT_DIR/cozip-compress-details-servicemenu.desktop" "$SERVICEMENU_DIR/cozip-30-compress-details.desktop"
install_desktop_template "$SCRIPT_DIR/cozip-extract-here-servicemenu.desktop" "$SERVICEMENU_DIR/cozip-10-extract-here.desktop"
install_desktop_template "$SCRIPT_DIR/cozip-extract-details-servicemenu.desktop" "$SERVICEMENU_DIR/cozip-20-extract-details.desktop"
chmod +x \
  "$SERVICEMENU_DIR/cozip-10-compress-zip.desktop" \
  "$SERVICEMENU_DIR/cozip-20-compress-cozip.desktop" \
  "$SERVICEMENU_DIR/cozip-30-compress-details.desktop" \
  "$SERVICEMENU_DIR/cozip-10-extract-here.desktop" \
  "$SERVICEMENU_DIR/cozip-20-extract-details.desktop"

echo "==> Installing file-manager scripts (GNOME/Cinnamon/MATE)..."
install_filemanager_common
install_filemanager_scripts_into "$NAUTILUS_SCRIPT_DIR"
install_filemanager_scripts_into "$NEMO_SCRIPT_DIR"
install_filemanager_scripts_into "$CAJA_SCRIPT_DIR"

echo "==> Refreshing desktop caches..."
refresh_desktop_caches

echo ""
echo "Done! Installed $COZIP_DESKTOP_BIN."
echo "You may need to restart Dolphin (or log out/in) for the service menus to appear."
echo "On GNOME/Cinnamon/MATE the actions appear under the right-click \"Scripts\" submenu."
