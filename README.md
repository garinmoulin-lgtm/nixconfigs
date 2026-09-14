AptNix - Git repo originating as a backup configuration file - evolved into a "distribution" of
NixOS, *apt* for any task - whether it be gaming, coding, browsing, or business meetings.

AptNix comes with essential codecs, drivers, and performance patches pre-included and tailored for 
a smooth desktop experience. 

Note that AptNix opts for primarily terminal based tools, and tries to keep the experience as light as
possible. For example, the music player "Amberol" has been replaced with *kew*, a terminal based music player.

It does not come with an image viewer pre-installed. However such programs can be temporarily installed and used
via nix-shell -p {PROGRAM} and used temporarily. If you want to add such programs for yourself I suggest
using nix profile, however you may append it as you please to configuration.nix.

I cannot emphasize this enough but it is *absolutely necessary* that you read through the *entire* README.

## Installation
Copy and paste the block below to install.
```bash
git clone https://github.com/garinmoulin-lgtm/nixconfigs
cd nixconfigs
chmod +x install.sh
./install.sh
```

## Tips

If you want a piece of software and it is not installed, you may temporarily use it using nix-shell:

```nix
nix-shell -p {PROGRAM}
```
But if you want many packages (i.e. as a kernel dev, programmer) and cannot memorize them you may use 
a file called a *shell.nix*. This file is used to outline which packages to use, and when done, simply garbage
collect using nh clean.

Example of shell.nix:

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "kernel-build-shell";

  buildInputs = with pkgs; [
	# Programs go here
  ];

  shellHook = ''
    echo "whatever you want to indicate your shell is ready"
  '';
}
```

## Aliases
AptNix is built with aliases in mind. What do aliases do? Save you a lot of hassle from memorizing long strings of code.
Here's my list of Aliases:
```bash
alias -- gs='git status'
alias -- clean='nh clean all'
alias -- ll='ls -la'
alias -- update='cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure && cd && flatpak update -y'
alias -- viconfig='sudo fresh /etc/nixos/configuration.nix'
```
TL;DR:

Most of these aliases come with nixos.
- ll is to see permissions.
- gs is another built in alias to check, well, git status.
- clean is to wipe build cache, temporary leftovers from nix-shell apps, and remove old generations.
- update... you guessed it! Updates, and rebuilds the system.
- viconfig is based off of a similar concept to visudo - allows you to edit the configuration.nix via fresh-editor.


## Additional information
Dotfiles, to be redistributable, are configured and managed declaratively via home-manager. As a result, it's a bit harder 
to manage configurations and change them. You can either edit directly via home.nix, or alternatively, open another
window with the dotfile from .config pasted into it, edit there, and paste it into home.nix.

You *need* to put the wallpaper at:

```bash
~/Pictures/Wallpapers/hk.png
```

I made that up kind of a long time ago, but it needs to be there, and only there.

Also just a clear reminder I did copy the rofi configuration straight from Archcraft, modified colors and angles, and called it a day.
I still hope you'll enjoy!

## FAQ
Q: Is this distro actively maintained?

A: Sort of. It is primarily me sharing my configuration with the world. So it is maintained by me. However programs may be 
opinionated in a certain way, so feel free to contact me.

Q: Who is this for?

A: Primarily enthusiasts, minimalists, tinkerers, etc. Trying to make NixOS easier, and premade apt for anything.

## Screenshots (will add more, or you can contribute!)
<img src="https://i.imgur.com/8pJybPQ.png">
<img src="https://i.imgur.com/eZQIwd9.png">

## Current Wallpaper Collection (again, expect more in the future)
<img src="https://i.imgur.com/T96Rzme.jpeg">

E-mail me for suggestions (for anything related to this page) at garinmoulin@gmail.com
