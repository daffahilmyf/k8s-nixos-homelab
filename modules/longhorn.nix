{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.longhorn;
  isControl = config.custom.role == "control-plane";
  isFirstControl = config.networking.hostName == config.custom.cluster.firstControl;
  deployScript = pkgs.writeScriptBin "longhorn-deploy" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    until kubectl get --raw=/readyz >/dev/null 2>&1; do
      sleep 1
    done
    kubectl apply -f "${cfg.manifestUrl}"
  '';
in {
  options.custom.longhorn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install Longhorn node prerequisites and optionally deploy the manifest.";
    };

    deploy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Apply the Longhorn manifest from manifestUrl on control-plane nodes.";
    };

    manifestUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml";
      description = "URL for the Longhorn deployment manifest.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openiscsi.enable = true;
    environment.systemPackages = with pkgs; [
      openiscsi
      nfs-utils
    ];

    systemd.services.longhornDeploy = lib.mkIf (cfg.deploy && isControl && isFirstControl) {
      description = "Deploy Longhorn after the control plane is ready.";
      wants = ["k3s.service"];
      after = ["k3s.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        Environment = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml";
        ExecStart = "${deployScript}/bin/longhorn-deploy";
      };
    };
  };
}
