{
  config,
  pkgs,
  lib,
  ...
}: let
  sopsUnit = "sops-nix.service";
  sopsDeps = lib.optionals (config.systemd.services ? "sops-nix") [sopsUnit];
in {
  sops.secrets.cloudflared_token = {
    sopsFile = ./../secrets/cloudflared-token.yaml;
    path = "/var/lib/cloudflared/token";
    owner = "root";
    mode = "0600";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/cloudflared 0700 root root -"
  ];

  systemd.services.cloudflared = {
    enable = true;
    description = "Cloudflare Tunnel";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"] ++ sopsDeps;
    after = ["network-online.target"] ++ sopsDeps;
    requires = sopsDeps;

    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel run --token-file /var/lib/cloudflared/token";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
