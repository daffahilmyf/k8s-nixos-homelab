{
  config,
  pkgs,
  lib,
  ...
}: let
  authCfg = config.custom.auth;
  rootPasswordSecretPath = lib.attrByPath ["sops" "secrets" "root_password_hash" "path"] config null;
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
      (lib.mkIf (authCfg.rootPassword == null && rootPasswordSecretPath != null) {
        hashedPasswordFile = rootPasswordSecretPath;
      })
      (lib.mkIf (authCfg.rootPassword != null) {
        initialPassword = authCfg.rootPassword;
      })
    ];

    assertions = [
      {
        assertion = (authCfg.rootPassword != null) || (rootPasswordSecretPath != null);
        message = "Provide custom.auth.rootPassword or define the sops secret root_password_hash (see secrets/root-password.yaml).";
      }
    ];

    system.stateVersion = "25.05";
  };
}
