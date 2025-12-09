{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.custom.kustomizeDeploy;
  renderOverlayScript = lib.concatMapStringsSep "\n" (overlay: let
    path = overlay.path;
    name = overlay.name or path;
    waitCommands = overlay.waitCommands or [];
    waitScript =
      if waitCommands == []
      then ""
      else ''
        ${lib.concatMapStringsSep "\n" (cmd: "        ${cmd}") waitCommands}
      '';
  in ''
    echo "Applying ${name}"
    kustomize build "${path}" | kubectl apply -f -
    ${waitScript}
  '') cfg.overlays;

  deployScript = pkgs.writeScriptBin "kustomize-deploy" ''
    set -euo pipefail
    until kubectl get --raw=/readyz >/dev/null 2>&1; do
      sleep 1
    done
    ${renderOverlayScript}
  '';
in {
  options.custom.kustomizeDeploy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Apply Kubernetes manifests via kustomize overlays after each rebuild.";
    };

    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "List of overlay descriptors that should be applied when enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.overlays != [];
        message = "custom.kustomizeDeploy.overlays must list at least one overlay when enabled.";
      }
      {
        assertion = lib.all (overlay: lib.hasAttr "path" overlay) cfg.overlays;
        message = "Each entry in custom.kustomizeDeploy.overlays must contain a path attribute.";
      }
    ];

    custom.kustomize.enable = lib.mkForce true;

    systemd.services.kustomizeDeploy = {
      description = "Apply Kubernetes kustomize overlays after the control plane is ready.";
      wants = [ "k3s.service" ];
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        Environment = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml";
        ExecStart = "${deployScript}/bin/kustomize-deploy";
      };
    };
  };
}
