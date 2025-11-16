{
  config,
  pkgs,
  lib,
  ...
}: {
  sops.secrets.cloudflared_token = {
    sopsFile = ./../secrets/cloudflared-token.yaml;
    path = "/etc/cloudflared/token";
    owner = "root";
    mode = "0600";
  };

  systemd.tmpfiles.rules = [
    "d /etc/cloudflared 0755 root root -"
  ];

  systemd.services.cloudflared = {
    enable = true;
    description = "Cloudflare Tunnel";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];

    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel run --token-file /etc/cloudflared/token";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
