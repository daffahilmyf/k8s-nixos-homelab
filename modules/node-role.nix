{
  lib,
  config,
  pkgs,
  ...
}: let
  hostname = config.networking.hostName;
  fallbackRole =
    if lib.hasInfix "control" hostname
    then "control-plane"
    else "worker";
  cfg = config.custom.role;
  resolvedRole = if cfg != null then cfg else fallbackRole;
in {
  # Role option
  options.custom.role = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum ["control-plane" "worker"]);
    default = null;
    description = "Kubernetes node role (must be set per host).";
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg != null;
          message = "custom.role must be set per host (see hosts/k3s-control-1.nix and the README).";
        }
      ];
    }

    {
      services.k3s = {
        role = if resolvedRole == "control-plane" then "server" else "agent";
        clusterInit = lib.mkIf (resolvedRole == "control-plane") true;
      };
    }

    (lib.mkIf (resolvedRole == "control-plane") {
      environment.systemPackages = [
        pkgs.kubectl
        pkgs.kubernetes-helm
        pkgs.k9s
      ];
    })
  ];
}
