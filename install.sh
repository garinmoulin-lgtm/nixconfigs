#!/usr/bin/env bash

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

# Update the username globally across all .nix files in the current directory
echo "Updating username across configuration files..."
sed -i "s/garinh/$sys_user/g" ./*.nix

# Update the Hyprland monitor output and mode inside home.nix
echo "Updating display configuration in home.nix..."
sed -i "s/output   = \"DP-3\"/output   = \"$disp_out\"/g" ./home.nix
sed -i "s/mode     = \"1920x1080@240\"/mode     = \"$disp_mode\"/g" ./home.nix

# Proceed with the original installation routine
echo "copying configuration files..."
cp ./*.nix /etc/nixos/

echo "installing the distro..."
cd /etc/nixos && nix flake update && nixos-rebuild switch --flake /etc/nixos#nixos --impure && cd && flatpak update -y

echo "Installation complete."
echo "OS installed!"
