{ ... }:

{
  imports = [
    (import ./common.nix {
      name = "sonarr";
      image = "docker.io/linuxserver/sonarr:4.0.20.3014-ls329@sha256:44b06045a98bc1f237b9ffefc4b28dab64cb29305e4a2a94875ae93b5224e4cc";
      port = 8989;
      tailscaleDefault = true;

      extraVolumes = [
        "/mnt/shares/Downloads/Series:/downloads"
        "/mnt/shares/Media/Series:/media"
      ];
    })
  ];
}
