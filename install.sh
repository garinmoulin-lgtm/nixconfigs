#!/usr/bin/env bash
set -euo pipefail

# --- Fail loudly, with the line number, instead of silently continuing ---
trap 'echo -e "\n[FAILED] Script aborted on line $LINENO. Last command exit code: $?" >&2' ERR

# 1. Require root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi

# 2. Prompt users for system username
read -p "Enter the new username for the system: " sys_user

# 3. Prompt users for display configuration
echo "Hyprland Display Configuration"
read -p "Enter your display output (e.g., eDP-1, DP-1, DP-3): " disp_out
read -p "Enter your display mode (e.g., 1920x1080@60, 2560x1440@144): " disp_mode

# 4. Prompt users for Kernel choice
echo "Select Kernel:"
echo "1) Base (latest)"
echo "2) CachyOS"
read -p "Which kernel do you want to use? (See configuration.nix comment for details) [1-2]: " kernel_choice

# 5. Prompt users for GPU choice
echo "Select GPU Driver:"
echo "1) Intel"
echo "2) Nvidia"
echo "3) AMD"
read -p "Which GPU driver do you want to use? [1-3]: " gpu_choice

# 6. Prompt users for Touchpad
echo "Do you have a touchpad?"
echo "1) Yes"
echo "2) No"
read -p "Enable touchpad support? [1-2]: " touchpad_choice

# --- ARCHITECTURE CHANGE: Modify files locally before copying ---
echo "Updating configuration files locally in $(pwd)..."
sed -i "s/garinh/$sys_user/g" ./*.nix
sed -i "s/output   = \"DP-3\"/output   = \"$disp_out\"/g" ./home.nix
sed -i "s/mode     = \"1920x1080@240\"/mode     = \"$disp_mode\"/g" ./home.nix

if [ "$kernel_choice" = "1" ]; then
    echo "Setting kernel to linuxPackages_latest..."
    sed -i 's/boot.kernelPackages = pkgs.linuxPackages_cachyos;/boot.kernelPackages = pkgs.linuxPackages_latest;/g' ./configuration.nix
elif [ "$kernel_choice" = "2" ]; then
    echo "Keeping kernel as linuxPackages_cachyos..."
else
    echo "Invalid kernel choice, defaulting to Base (latest)..."
    sed -i 's/boot.kernelPackages = pkgs.linuxPackages_cachyos;/boot.kernelPackages = pkgs.linuxPackages_latest;/g' ./configuration.nix
fi

if [ "$gpu_choice" = "1" ]; then
    echo "Applying Intel GPU configuration..."
    sed -i 's/services.xserver.videoDrivers = \[ "nvidia" \];/services.xserver.videoDrivers = \[ "intel" \];/g' ./configuration.nix
    # Remove any existing kernelModules line first to avoid duplicates
    sed -i '/boot.initrd.kernelModules = \[ "i915" \];/d' ./configuration.nix
    sed -i '/boot.initrd.kernelModules = \[ "amdgpu" \];/d' ./configuration.nix
    sed -i '/boot.blacklistedKernelModules = \[ "acpi_pad" "nouveau" \];/a \ \ boot.initrd.kernelModules = [ "i915" ];' ./configuration.nix
    sed -i '/hardware.nvidia = {/,/};/s/^/#/' ./configuration.nix
    sed -i '/boot.extraModprobeConfig =/,/;/s/^/#/' ./configuration.nix
    sed -i '/boot.kernelParams = \[ "nvidia-drm.modeset=1" \];/s/^/#/' ./configuration.nix
    sed -i '/WLR_NO_HARDWARE_CURSORS = "1";/s/^/#/' ./configuration.nix
    sed -i 's/hl.env("LIBVA_DRIVER_NAME", "nvidia")/-- hl.env("LIBVA_DRIVER_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("GBM_BACKEND", "nvidia-drm")/-- hl.env("GBM_BACKEND", "nvidia-drm")/g' ./home.nix
elif [ "$gpu_choice" = "3" ]; then
    echo "Applying AMD GPU configuration..."
    sed -i 's/services.xserver.videoDrivers = \[ "nvidia" \];/services.xserver.videoDrivers = \[ "amdgpu" \];/g' ./configuration.nix
    # Remove any existing kernelModules line first to avoid duplicates
    sed -i '/boot.initrd.kernelModules = \[ "i915" \];/d' ./configuration.nix
    sed -i '/boot.initrd.kernelModules = \[ "amdgpu" \];/d' ./configuration.nix
    sed -i '/boot.blacklistedKernelModules = \[ "acpi_pad" "nouveau" \];/a \ \ boot.initrd.kernelModules = [ "amdgpu" ];' ./configuration.nix
    sed -i '/hardware.nvidia = {/,/};/s/^/#/' ./configuration.nix
    sed -i '/boot.extraModprobeConfig =/,/;/s/^/#/' ./configuration.nix
    sed -i '/boot.kernelParams = \[ "nvidia-drm.modeset=1" \];/s/^/#/' ./configuration.nix
    sed -i '/WLR_NO_HARDWARE_CURSORS = "1";/s/^/#/' ./configuration.nix
    sed -i 's/hl.env("LIBVA_DRIVER_NAME", "nvidia")/-- hl.env("LIBVA_DRIVER_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")/g' ./home.nix
    sed -i 's/hl.env("GBM_BACKEND", "nvidia-drm")/-- hl.env("GBM_BACKEND", "nvidia-drm")/g' ./home.nix
elif [ "$gpu_choice" = "2" ]; then
    echo "Keeping standard Nvidia GPU configuration..."
else
    echo "Invalid GPU choice, keeping default (Nvidia)..."
fi

if [ "$touchpad_choice" = "1" ]; then
    echo "Enabling touchpad support..."
    sed -i 's/# services.xserver.libinput.enable = true;/services.xserver.libinput.enable = true;/g' ./configuration.nix
else
    echo "Keeping touchpad support disabled..."
fi

# --- Sanity check: fail loudly if the sed edits produced a duplicate kernelModules line ---
dup_count=$(grep -c 'boot.initrd.kernelModules' ./configuration.nix || true)
if [ "$dup_count" -gt 1 ]; then
    echo "[FAILED] configuration.nix has $dup_count 'boot.initrd.kernelModules' lines (expected 1). Aborting before copy." >&2
    grep -n 'boot.initrd.kernelModules' ./configuration.nix >&2
    exit 1
fi

echo "Copying modified configuration files to /etc/nixos..."
cp ./*.nix /etc/nixos/

# --- BUG FIXES: Exporting required Nix configuration flags ---
echo "Exporting NIX_CONFIG flags to prevent flake installation failures..."
export NIX_CONFIG="experimental-features = nix-command flakes
warn-dirty = false"

echo "Staging new config files in git (required for flakes to see them)..."
cd /etc/nixos

# Avoid "detected dubious ownership" fatal error when running as root
git config --global --add safe.directory /etc/nixos

# Initialize the repo if this is a fresh install with no git history yet
if [ ! -d .git ]; then
    echo "No git repo found in /etc/nixos, initializing one..."
    git init
    git add -A
    git commit -m "Initial NixOS configuration" --quiet
else
    git add -A
fi

echo "Running nix flake update..."
if ! nix flake update; then
    echo "[FAILED] nix flake update failed. Aborting before rebuild." >&2
    exit 1
fi

echo "Running nixos-rebuild switch..."
if ! nixos-rebuild switch --flake /etc/nixos#nixos --impure; then
    echo "[FAILED] nixos-rebuild switch failed. System was NOT switched to the new configuration." >&2
    exit 1
fi

cd -

echo "Running flatpak update..."
if ! flatpak update -y; then
    echo "[WARNING] flatpak update failed, but NixOS rebuild already succeeded. Continuing." >&2
fi

echo "Installation complete."
echo "OS installed!"
