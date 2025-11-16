{
  config,
  pkgs,
  lib,
  ...
}: {
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

  services.openssh.settings = {
    PermitRootLogin = lib.mkDefault "no";
    PasswordAuthentication = lib.mkDefault false;
  };

  # Root password hash is delivered via sops secret (see modules/sops.nix).
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;

  assertions = [
    {
      assertion = config.sops.secrets.root_password_hash.path != null;
      message = "sops secret root_password_hash must be defined (see secrets/root-password.yaml).";
    }
  ];

  system.stateVersion = "25.05";
}
