# CONFIG

[![](https://img.shields.io/badge/aloshy.🅰🅸-000000.svg?style=for-the-badge)](https://aloshy.ai)
[![Powered By Nix](https://img.shields.io/badge/NIX-POWERED-5277C3.svg?style=for-the-badge&logo=nixos)](https://nixos.org)
[![Platform](https://img.shields.io/badge/MACOS-ONLY-000000.svg?style=for-the-badge&logo=apple)](https://github.com/aloshy/config)
[![Build Status](https://img.shields.io/badge/BUILD-PASSING-success.svg?style=for-the-badge&logo=github)](https://github.com/aloshy-ai/config/actions)
[![License](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

One Nix flake to rule them all.

<!-- gen-readme start - generated by https://github.com/jetify-com/devbox/ -->
## Getting Started
This project uses [devbox](https://github.com/jetify-com/devbox) to manage its development environment.

Install devbox:
```sh
curl -fsSL https://get.jetpack.io/devbox | bash
```

Start the devbox shell:
```sh 
devbox shell
```

Run a script in the devbox environment:
```sh
devbox run <script>
```
## Scripts
Scripts are custom commands that can be run using this project's environment. This project has the following scripts:

* [build-rpi4](#devbox-run-build-rpi4)
* [darwin-rebuild](#devbox-run-darwin-rebuild)
* [format](#devbox-run-format)

## Shell Init Hook
The Shell Init Hook is a script that runs whenever the devbox environment is instantiated. It runs 
on `devbox shell` and on `devbox run`.
```sh
devbox run --list
```

## Packages

* github:snowfallorg/flake
* [nodePackages.prettier@latest](https://www.nixhub.io/packages/nodePackages.prettier)
* [cachix@latest](https://www.nixhub.io/packages/cachix)
* [fh@latest](https://www.nixhub.io/packages/fh)

## Script Details

### devbox run build-rpi4
```sh
nix build .#sd-aarch64Configurations.rpi4
```
&ensp;

### devbox run darwin-rebuild
```sh
nix run github:LnL7/nix-darwin#darwin-rebuild -- switch --flake .#silicon
```
&ensp;

### devbox run format
```sh
nix fmt .
```
&ensp;



<!-- gen-readme end -->
