{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # Local AGE key
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Ensure directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/sops-nix 0700 root root -"
  ];

  # Root password hash secret used during activation.
  sops.secrets.root_password_hash = {
    sopsFile = ./../secrets/root-password.yaml;
    mode = "0400";
    owner = "root";
  };

  # Shared k3s cluster token used by control plane and workers.
  sops.secrets.k3s_token = {
    sopsFile = ./../secrets/k3s-token.yaml;
    mode = "0400";
    owner = "root";
    path = "/var/lib/rancher/k3s/server/token";
  };
}
