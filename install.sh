#!/usr/bin/env bash
set -euo pipefail

# --- Fail loudly, with the line number, instead of silently continuing ---
trap 'echo -e "\n[FAILED] install.sh aborted on line $LINENO. Last command exit code: $?" >&2' ERR

# 1. Require root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (using sudo)."
  exit 1
fi

# 2. Prompt for system username
read -p "Enter the new username for the system: " sys_user

# Validate it BEFORE using it in sed — an empty or malformed value here would
# either no-op every substitution or, worse, get interpreted as sed regex/
# replacement syntax (/, &, \) and corrupt the config files silently.
if [[ ! "$sys_user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "Error: '$sys_user' is not a valid Linux username." >&2
    echo "Use lowercase letters, digits, '-' or '_', starting with a letter or '_'." >&2
    exit 1
fi

# 3. Prompt for Kernel choice
echo "Select Kernel:"
echo "1) Base (latest)"
echo "2) CachyOS"
read -p "Which kernel do you want to use? (See configuration.nix comment for details) [1-2]: " kernel_choice

# 4. Prompt for GPU choice
echo "Select GPU Driver:"
echo "1) Intel"
echo "2) Nvidia"
echo "3) AMD"
read -p "Which GPU driver do you want to use? [1-3]: " gpu_choice

# 5. Prompt for Touchpad
echo "Do you have a touchpad?"
echo "1) Yes"
echo "2) No"
read -p "Enable touchpad support? [1-2]: " touchpad_choice

# Locates ble.sh after the rebuild below, to confirm
# `programs.bash.blesh.enable = true;` actually took effect. How it's wired
# in (confirmed against nixpkgs source, nixos/modules/programs/bash/blesh.nix):
# the module sets
#   programs.bash.interactiveShellInit = lib.mkBefore ''
#     source ${pkgs.blesh}/share/blesh/ble.sh
#   '';
# which NixOS's bash module bakes into /etc/bashrc as a literal
# `source /nix/store/<hash>-blesh-<version>/share/blesh/ble.sh` line.
# That's the authoritative place to look — not /etc/profile.d, and not a
# blind /nix/store scan (slow, and can match unrelated things).
find_blesh() {
    # 1. Authoritative: read the resolved store path straight out of /etc/bashrc.
    if [ -r /etc/bashrc ]; then
        local found
        found="$(grep -oE '/nix/store/[^ ]+/share/blesh/ble\.sh' /etc/bashrc 2>/dev/null | head -n1 || true)"
        if [ -n "$found" ] && [ -f "$found" ]; then
            echo "$found"
            return 0
        fi
    fi

    # 2. Fallback: search the Nix store directly for the package directory.
    #    Scoped with -maxdepth so it doesn't crawl the entire store.
    local store_found
    store_found="$(find /nix/store -maxdepth 1 -type d -name 'blesh-*' 2>/dev/null | sort -V | tail -n1 || true)"
    if [ -n "$store_found" ] && [ -f "$store_found/share/blesh/ble.sh" ]; then
        echo "$store_found/share/blesh/ble.sh"
        return 0
    fi

    return 1
}

# 6. Detect and prompt for CPU core count to use during the build.
#    Relevant because from-source builds (e.g. linux_cachyos, if its binary
#    cache isn't trusted yet — see the note printed after kernel_choice=2
#    below) can OOM on memory-constrained VMs when Nix parallelizes too
#    aggressively. Try a few detection methods in order of preference.
detect_cores() {
    if command -v nproc >/dev/null 2>&1; then
        nproc --all
        return
    fi
    if [ -r /proc/cpuinfo ]; then
        grep -c '^processor' /proc/cpuinfo
        return
    fi
    if command -v lscpu >/dev/null 2>&1; then
        lscpu -p=CPU 2>/dev/null | grep -c '^[0-9]'
        return
    fi
    echo 1
}

detected_cores="$(detect_cores)"
echo "Detected $detected_cores CPU thread(s)."
if [ "$kernel_choice" = "2" ]; then
    echo "Note: CachyOS kernel builds are memory-hungry if built from source"
    echo "(happens whenever the chaotic-nyx binary cache isn't trusted yet"
    echo "on this system). If you're on a VM with limited RAM, consider"
    echo "using fewer cores than detected to reduce peak memory usage."
fi
read -p "How many cores should Nix use for building? [default: $detected_cores]: " chosen_cores
chosen_cores="${chosen_cores:-$detected_cores}"

if ! [[ "$chosen_cores" =~ ^[0-9]+$ ]] || [ "$chosen_cores" -lt 1 ]; then
    echo "Invalid input, defaulting to $detected_cores." >&2
    chosen_cores="$detected_cores"
fi
if [ "$chosen_cores" -gt "$detected_cores" ]; then
    echo "Warning: requested $chosen_cores exceeds detected $detected_cores; using $detected_cores instead." >&2
    chosen_cores="$detected_cores"
fi
echo "Using $chosen_cores core(s) for this build."

# --- Modify files locally before copying ---
echo "Updating configuration files locally in $(pwd)..."
sed -i "s/garinh/$sys_user/g" ./*.nix

# Sanity check: make sure the username substitution actually took everywhere.
# (Skip the check if the user genuinely chose "garinh" as their username.)
if [ "$sys_user" != "garinh" ]; then
    if grep -l "garinh" ./*.nix >/dev/null 2>&1; then
        echo "[FAILED] Leftover 'garinh' still found after substitution in:" >&2
        grep -l "garinh" ./*.nix >&2
        exit 1
    fi
fi

# Persist the chosen core count into configuration.nix so future rebuilds
# (including post-install.sh's) respect it without needing the flag again.
# Remove any pre-existing lines first — same dedup logic as the kernelModules
# fix below — so re-running this script doesn't stack duplicate declarations.
sed -i '/nix.settings.cores = [0-9]*;/d' ./configuration.nix
sed -i '/nix.settings.max-jobs = [0-9]*;/d' ./configuration.nix
sed -i "/nix.settings.trusted-users = \[ \"root\" \"$sys_user\" \];/a\\
  nix.settings.cores = $chosen_cores;\\
  nix.settings.max-jobs = $chosen_cores;" ./configuration.nix

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

# Same check for the cores/max-jobs settings we just inserted.
cores_dup_count=$(grep -c 'nix.settings.cores = ' ./configuration.nix || true)
if [ "$cores_dup_count" -gt 1 ]; then
    echo "[FAILED] configuration.nix has $cores_dup_count 'nix.settings.cores' lines (expected 1). Aborting before copy." >&2
    grep -n 'nix.settings.cores = ' ./configuration.nix >&2
    exit 1
fi

echo "Copying modified configuration files to /etc/nixos..."
cp ./*.nix /etc/nixos/

# --- Exporting required Nix configuration flags (belt-and-suspenders; the
#     config also sets nix.settings.experimental-features permanently, but
#     that only takes effect AFTER the first successful switch below) ---
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

    # Ensure git has an identity to commit with (root often has none set)
    if [ -z "$(git config --global user.email || true)" ]; then
        git config --global user.email "root@nixos.local"
    fi
    if [ -z "$(git config --global user.name || true)" ]; then
        git config --global user.name "NixOS Install Script"
    fi

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

# --cores is passed explicitly here because the nix.settings.cores value we
# just persisted into configuration.nix only takes effect system-wide AFTER
# a successful switch (it's applied during activation, not evaluation) — so
# for THIS first build, the file alone isn't enough; the flag makes sure the
# chosen core count is actually honored on this initial run too.
echo "Running nixos-rebuild switch (using $chosen_cores core(s))..."
if ! nixos-rebuild switch --flake /etc/nixos#nixos --impure --cores "$chosen_cores"; then
    echo "[FAILED] nixos-rebuild switch failed. System was NOT switched to the new configuration." >&2
    exit 1
fi

cd -

echo "Running flatpak update..."
if ! flatpak update -y; then
    echo "[WARNING] flatpak update failed, but NixOS rebuild already succeeded. Continuing." >&2
fi

echo "Verifying blesh installation..."
if blesh_path="$(find_blesh)"; then
    echo "Found ble.sh: $blesh_path"
else
    echo "[WARNING] Could not locate ble.sh after the rebuild." >&2
    echo "Check that 'programs.bash.blesh.enable = true;' is set in configuration.nix." >&2
fi

echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Reboot."
echo "  2. Log into Hyprland."
echo "  3. Run post-install.sh (as your normal user, NOT with sudo) to"
echo "     auto-detect your monitor and finish the display configuration."
