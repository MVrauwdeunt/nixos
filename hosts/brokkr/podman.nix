
{ pkgs, ... }:

{
  # Dedicated unprivileged CI account.
  users.groups.forgejo-runner = {};

  users.users.forgejo-runner = {
    isNormalUser = true;
    group = "forgejo-runner";
    description = "Forgejo CI Runner";

    home = "/var/lib/forgejo-runner";
    createHome = true;
    homeMode = "0700";

    shell = pkgs.shadow + "/bin/nologin";
    hashedPassword = "!";

    extraGroups = [];
    autoSubUidGidRange = true;
    linger = true;
  };

  # Rootless container runtime.
  virtualisation = {
    containers = {
      enable = true;

      containersConf.settings.containers = {
        dns_servers = [ "169.254.1.2" ];
      };
    };

    podman = {
      enable = true;
      dockerCompat = false;
      dockerSocket.enable = false;
    };

    docker.enable = false;
  };

  # Dedicated split-DNS resolver for CI containers.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;

    settings = {
      listen-address = "192.168.60.10";
      bind-dynamic = true;

      no-resolv = true;
      no-hosts = true;

      server = [
        "192.168.60.254"
        "/ts.net/100.100.100.100"
      ];

      cache-size = 1000;
    };
  };
}
