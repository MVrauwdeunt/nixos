
{ pkgs }:

let
  tools = with pkgs; [
    nix
    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    git
    curl
    cacert
    nodejs_24
    jq
    gzip
    gnutar
    xz
    unzip
    which
    statix
    deadnix
    nixfmt
    gitleaks
    sops
    shellcheck
  ];

  nixConfig = pkgs.writeTextDir "etc/nix/nix.conf" ''
    experimental-features = nix-command flakes
    sandbox = false
    build-users-group =
    require-sigs = true
  '';

in
pkgs.dockerTools.buildLayeredImage {
  name = "brokkr-ci";
  tag = "1.0.0";

  contents = tools ++ [
    nixConfig
    pkgs.dockerTools.caCertificates
    pkgs.dockerTools.fakeNss
  ];

  includeNixDB = true;

  extraCommands = ''
    mkdir -p root tmp workspace usr/bin

    chmod 1777 tmp

    ln -s ${pkgs.coreutils}/bin/env usr/bin/env
  '';

  config = {
    Cmd = [ "${pkgs.bash}/bin/bash" ];

    WorkingDir = "/workspace";

    Env = [
      "PATH=/bin:/usr/bin"
      "HOME=/root"
      "USER=root"
      "NIX_REMOTE=local"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
