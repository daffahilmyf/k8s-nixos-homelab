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
}
