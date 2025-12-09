{
  config,
  pkgs,
  lib,
  ...
}: let
  authCfg = config.custom.auth;
  rootPasswordSecret = lib.attrByPath ["sops" "secrets" "root_password_hash"] config null;
  rawRootPasswordValue =
    if rootPasswordSecret != null && builtins.isAttrs rootPasswordSecret && builtins.hasAttr "value" rootPasswordSecret
    then rootPasswordSecret.value
    else null;
  resolvedRootPasswordValue =
    if rawRootPasswordValue == null
    then null
    else if lib.isString rawRootPasswordValue
    then rawRootPasswordValue
    else if builtins.isAttrs rawRootPasswordValue && builtins.hasAttr "root_password_hash" rawRootPasswordValue
    then rawRootPasswordValue.root_password_hash
    else null;
  rootPasswordHash =
    if lib.isString resolvedRootPasswordValue
    then resolvedRootPasswordValue
    else null;
in {
  options.custom.auth = {
    rootPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Plaintext root password for initial deployments (use only in trusted environments).";
    };
  };

  config = {
    boot = {
      kernel.sysctl = {
        "net.bridge.bridge-nf-call-iptables" = 1;
        "net.ipv4.ip_forward" = 1;
      };

      kernelModules = ["br_netfilter"];

      kernelParams = [
        "cgroup_enable=cpuset"
        "cgroup_enable=memory"
        "cgroup_memory=1"
      ];

      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    };

    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
      };
    };

    users.users.root = lib.mkMerge [
      (lib.mkIf (authCfg.rootPassword == null && rootPasswordHash != null) {
        hashedPassword = rootPasswordHash;
      })
      (lib.mkIf (authCfg.rootPassword != null) {
        initialPassword = authCfg.rootPassword;
      })
    ];

    assertions = [
      {
        assertion = (authCfg.rootPassword != null) || (rootPasswordHash != null);
        message = "Provide custom.auth.rootPassword or define the sops secret root_password_hash (see secrets/root-password.yaml).";
      }
    ];

    system.stateVersion = "25.05";
  };
}
