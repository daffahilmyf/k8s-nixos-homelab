{
  lib,
  config,
  pkgs,
  ...
}: let
  hostname = config.networking.hostName;

  # Auto-detect role
  role =
    if lib.hasInfix "control" hostname
    then "control-plane"
    else "worker";
in {
  # Role option
  options.custom.role = lib.mkOption {
    type = lib.types.enum ["control-plane" "worker"];
    default = role;
    description = "Kubernetes node role";
  };

  config = lib.mkMerge [
    {
      services.k3s = {
        role =
          if config.custom.role == "control-plane"
          then "server"
          else "agent";
        clusterInit = lib.mkIf (config.custom.role == "control-plane") true;
      };
    }

    (lib.mkIf (config.custom.role == "control-plane") {
      environment.systemPackages = [
        pkgs.kubectl
        pkgs.kubernetes-helm
        pkgs.k9s
      ];
    })
  ];
}
