#!/usr/bin/env bash
#simple script for installing my configs
echo "copying coniguration files... (requires sudo)"
sudo cp ./*.nix /etc/nixos/
echo "installing the distro..."
cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure && cd && flatpak update -y
echo "Installation complete."
echo "OS installed!"
