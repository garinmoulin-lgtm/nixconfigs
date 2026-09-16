#!/usr/bin/env bash
set -euo pipefail

# --- Fail loudly, with the line number, instead of silently continuing ---
trap 'echo -e "\n[FAILED] post-install.sh aborted on line $LINENO. Last exit code: $?" >&2' ERR

NIXOS_DIR="/etc/nixos"
HOME_NIX="$NIXOS_DIR/home.nix"
DEPLOYED_LUA="$HOME/.config/hypr/hyprland.lua"

# 1. Must run as your normal user, inside Hyprland — NOT root/sudo.
#    hyprctl talks to Hyprland's IPC socket, which lives in the logged-in
#    user's runtime dir; running this under sudo would look in root's
#    (nonexistent) session and fail or, worse, silently query nothing.
if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this with sudo/root." >&2
    echo "Run it as yourself, inside your Hyprland session — it calls sudo itself for the parts that need it." >&2
    exit 1
fi

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "Error: HYPRLAND_INSTANCE_SIGNATURE is not set." >&2
    echo "Run this from inside a running Hyprland session, not a TTY or another WM." >&2
    exit 1
fi

for bin in hyprctl jq sudo; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Error: '$bin' not found in PATH. Did the base install (install.sh) finish successfully?" >&2
        exit 1
    fi
done

if [ ! -f "$HOME_NIX" ]; then
    echo "Error: $HOME_NIX not found. Run install.sh first." >&2
    exit 1
fi

# 2. Query Hyprland for connected monitors as JSON (far more robust than
#    scraping hyprctl's human-readable text output, whose indentation/format
#    has changed across Hyprland versions).
echo "Querying hyprctl for connected monitors..."
mon_json="$(hyprctl monitors -j)"

if [ -z "$mon_json" ] || [ "$mon_json" = "[]" ]; then
    echo "Error: hyprctl reported no connected monitors." >&2
    exit 1
fi

# Prefer the focused monitor; fall back to the first one in the list if none
# is marked focused (can happen right after login in rare cases).
selected="$(echo "$mon_json" | jq -r '
  (map(select(.focused == true)) | .[0]) // .[0] |
  select(. != null) |
  "\(.name)|\(.width)x\(.height)@\(.refreshRate)|\(.x)x\(.y)|\(.scale)"
')"

if [ -z "$selected" ]; then
    echo "Error: could not parse a monitor from hyprctl's output." >&2
    echo "$mon_json" >&2
    exit 1
fi

IFS='|' read -r mon_name mon_mode mon_pos mon_scale <<< "$selected"

# hyprctl reports refresh rate with decimals (e.g. 144.00000) — round to an
# integer to match this project's existing config style ("1920x1080@240").
mon_res="${mon_mode%@*}"
mon_refresh_raw="${mon_mode#*@}"
mon_refresh="$(printf '%.0f' "$mon_refresh_raw")"
mon_mode_clean="${mon_res}@${mon_refresh}"
mon_scale_clean="$(printf '%.2f' "$mon_scale")"

echo ""
echo "Detected monitor:"
echo "  Output:   $mon_name"
echo "  Mode:     $mon_mode_clean"
echo "  Position: $mon_pos"
echo "  Scale:    $mon_scale_clean"
echo ""

# --- Sanity check: show exactly what's there BEFORE touching anything ---
echo "Current hl.monitor() block in $HOME_NIX:"
sudo grep -A4 'hl.monitor({' "$HOME_NIX" || true
echo ""

read -p "Apply this to home.nix and rebuild? [y/N]: " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted by user. No changes made."
    exit 0
fi

echo "Updating $HOME_NIX (requires sudo)..."
sudo sed -i "s/output   = \"[^\"]*\"/output   = \"$mon_name\"/" "$HOME_NIX"
sudo sed -i "s/mode     = \"[^\"]*\"/mode     = \"$mon_mode_clean\"/" "$HOME_NIX"
sudo sed -i "s/position = \"[^\"]*\"/position = \"$mon_pos\"/" "$HOME_NIX"
sudo sed -i "s/scale    = [0-9.]*/scale    = $mon_scale_clean/" "$HOME_NIX"

# --- Sanity check: prove the substitution actually took, at the SOURCE level,
#     before we even attempt a rebuild. If this doesn't show your new values,
#     the sed patterns didn't match this file (e.g. it was reformatted) and
#     the problem is here, not in the rebuild step below. ---
echo ""
echo "hl.monitor() block AFTER edit:"
sudo grep -A4 'hl.monitor({' "$HOME_NIX" || true
echo ""

if ! sudo grep -q "output   = \"$mon_name\"" "$HOME_NIX"; then
    echo "[FAILED] The edit did not take — output line in $HOME_NIX still doesn't match '$mon_name'." >&2
    echo "This usually means the file's formatting no longer matches what the sed patterns expect." >&2
    exit 1
fi

echo "Staging change in git (required for flakes to see it)..."
sudo git config --global --add safe.directory "$NIXOS_DIR"
sudo git -C "$NIXOS_DIR" add -A

echo "Rebuilding system with the detected display configuration..."
if ! sudo nixos-rebuild switch --flake "$NIXOS_DIR#nixos" --impure; then
    echo "[FAILED] nixos-rebuild switch failed. Your home.nix edits are saved but NOT yet applied." >&2
    echo "(If this failed while building a kernel from source, see the chaotic-nyx binary" >&2
    echo "cache note — that's a separate, known issue and not related to this script.)" >&2
    exit 1
fi

# --- Final sanity check: confirm the change actually reached the DEPLOYED
#     file, not just the source in /etc/nixos. This is the file Hyprland
#     itself reads, so this is the real proof the change took effect. ---
echo ""
echo "Verifying deployed config at $DEPLOYED_LUA..."
if [ -f "$DEPLOYED_LUA" ] && grep -q "output   = \"$mon_name\"" "$DEPLOYED_LUA"; then
    echo "Confirmed: $DEPLOYED_LUA now has output = \"$mon_name\"."
else
    echo "[WARNING] Could not confirm the new monitor settings in $DEPLOYED_LUA." >&2
    echo "The rebuild reported success, but the deployed file doesn't show the expected value." >&2
    echo "Try: hyprctl reload   (Hyprland may need an explicit reload to pick up the new file)" >&2
fi

echo ""
echo "Display configuration applied successfully."
echo "If your screen doesn't update immediately, run: hyprctl reload"
