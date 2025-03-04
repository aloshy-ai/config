{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
     alejandra
     starship
     busybox
     devbox
     direnv
     zsh
     git
     gh
  ];

  # Set zsh as the default shell and initialize devbox
  shellHook = ''
    export SHELL=$(which zsh)
    eval "$(devbox shellenv --init-hook)"
    eval "$(devbox generate direnv --print-envrc --env-file .env.local)"
  '';
}