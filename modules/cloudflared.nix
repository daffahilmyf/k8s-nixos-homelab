{
  config,
  pkgs,
  lib,
  ...
}: {
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
    after = ["network-online.target"];

    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel run --token-file /var/lib/cloudflared/token";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
