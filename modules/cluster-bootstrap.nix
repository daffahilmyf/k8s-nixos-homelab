{
  lib,
  config,
  pkgs,
  ...
}: let
  # Role helpers
  isControl = config.custom.role == "control-plane";
  isWorker = config.custom.role == "worker";

  # k3s token path
  tokenFile = "/var/lib/rancher/k3s/server/token";
in {
  # Control-plane: wait for token to appear
  systemd.services.k3s-bootstrap-token = lib.mkIf isControl {
    description = "Ensure k3s server token exists";
    after = ["k3s.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c ' \
        for i in {1..20}; do \
          if [ -f ${tokenFile} ]; then exit 0; fi; \
          echo \"Waiting for k3s token...\"; sleep 1; \
        done; \
        echo \"Token not found\"; \
      '";
    };
  };

  # Worker: fetch token from control-plane
  systemd.services.k3s-fetch-token = lib.mkIf isWorker {
    description = "Fetch k3s join token from control node";
    after = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c ' \
        mkdir -p /var/lib/rancher/k3s/server; \
        scp -o StrictHostKeyChecking=no \
          root@k3s-control-1:${tokenFile} \
          /var/lib/rancher/k3s/server/token; \
      '";
    };
  };

  # Worker join args
  services.k3s.extraFlags = lib.mkIf isWorker ''
    --server https://k3s-control-1:6443
    --token-file /var/lib/rancher/k3s/server/token
  '';
}
