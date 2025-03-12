{ options, config, pkgs, lib, ... }:

with lib;
let
  cfg = config.plusultra.security.gpg;
  gpgConf = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/drduh/config/master/gpg.conf";
    sha256 = "0va62sgnah8rjgp4m6zygs4z9gbpmqvq9m3x4byywk1dha6nvvaj";
  };
  gpgAgentConf = ''
    enable-ssh-support
    default-cache-ttl 60
    max-cache-ttl 120
    pinentry-program ${pkgs.pinentry-gnome}/bin/pinentry-gnome
  '';
  guide = pkgs.fetchurl {
    url =
      "https://raw.githubusercontent.com/drduh/YubiKey-Guide/master/README.md";
    sha256 = "164pyqm3yjybxlvwxzfb9mpp38zs9rb2fycngr6jv20n3vr1dipj";
  };
  theme = pkgs.fetchFromGitHub {
    owner = "jez";
    repo = "pandoc-markdown-css-theme";
    rev = "019a4829242937761949274916022e9861ed0627";
    sha256 = "1h48yqffpaz437f3c9hfryf23r95rr319lrb3y79kxpxbc9hihxb";
  };
  guideHTML = pkgs.runCommand "yubikey-guide" { } ''
    ${pkgs.pandoc}/bin/pandoc \
      --standalone \
      --metadata title="Yubikey Guide" \
      --from markdown \
      --to html5+smart \
      --toc \
      --template ${theme}/template.html5 \
      --css ${theme}/docs/css/theme.css \
      --css ${theme}/docs/css/skylighting-solarized-theme.css \
      -o $out \
      ${guide}
  '';
  guideDesktopItem = pkgs.makeDesktopItem {
    name = "yubikey-guide";
    desktopName = "Yubikey Guide";
    genericName = "View Yubikey Guide in a web browser";
    exec = "${pkgs.xdg-utils}/bin/xdg-open ${guideHTML}";
    icon = ./yubico-icon.svg;
    categories = [ "System" ];
  };
  reload-yubikey = pkgs.writeShellScriptBin "reload-yubikey" ''
    ${pkgs.gnupg}/bin/gpg-connect-agent "scd serialno" "learn --force" /bye
  '';
in {
  options.plusultra.security.gpg = {
    enable = mkBoolOpt false "Whether or not to enable GPG.";
  };

  config = mkIf cfg.enable {
    services.pcscd.enable = true;
    services.udev.packages = with pkgs; [ yubikey-personalization ];

    # @NOTE(jakehamilton): This should already have been added by programs.gpg, but
    # keeping it here for now just in case.
    environment.shellInit = ''
      export GPG_TTY="$(tty)"
      export SSH_AUTH_SOCK=$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)
      ${pkgs.gnupg}/bin/gpgconf --launch gpg-agent
    '';

    environment.systemPackages = with pkgs; [
      cryptsetup
      paperkey
      gnupg
      pinentry-curses
      pinentry-qt
      paperkey
      guideDesktopItem
      reload-yubikey
    ];

    programs = {
      ssh.startAgent = false;
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryFlavor = "gnome3";
      };
    };

    plusultra = {
      home.file = {
        ".gnupg/yubikey-guide.md".source = guide;
        ".gnupg/yubikey-guide.html".source = guideHTML;

        ".gnupg/gpg.conf".source = gpgConf;
        ".gnupg/gpg-agent.conf".text = gpgAgentConf;
      };
    };
  };
}
