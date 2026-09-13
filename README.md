AptNix - Git repo originating as a backup configuration file - evolved into a "distribution" of
NixOS, *apt* for any task - whether it be gaming, coding, browsing, or business meetings.

AptNix comes with essential codecs, drivers, and performance patches pre-included and tailored for 
a smooth desktop experience. 

Note that AptNix opts for primarily terminal based tools, and tries to keep the experience as light as
possible. For example, the music player "Amberol" has been replaced with *kew*, a terminal based music player.

It does not come with an image viewer pre-installed. However such programs can be temporarily installed and used
via nix-shell -p {PROGRAM} and used temporarily. If you want to add such programs for yourself I suggest
using nix profile, however you may append it as you please to configuration.nix.

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


## Current Wallpaper Collection (expect more in the future)
<img src="https://i.imgur.com/T96Rzme.jpeg">

E-mail me for suggestions (for anything related to this page) at garinmoulin@gmail.com
