{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.custom.kustomize;
in {
  options.custom.kustomize = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the kustomize CLI for managing Kubernetes manifests.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kustomize;
      description = "Derivation that provides the kustomize binary.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
