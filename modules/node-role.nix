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

  # k3s role binding
  config.services.k3s = {
    role =
      if config.custom.role == "control-plane"
      then "server"
      else "agent";
    clusterInit = lib.mkIf (config.custom.role == "control-plane") true;
  };

  # Control-plane tools
  config.environment.systemPackages = lib.mkIf (config.custom.role == "control-plane") [
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.k9s
  ];
}
