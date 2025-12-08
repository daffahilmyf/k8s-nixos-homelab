{
  inputs,
  config,
  lib,
  ...
}: let
  githubTokenPath = ./../secrets/github-token.yaml;
  githubTokenEnabled = builtins.pathExists githubTokenPath;
  githubTmpfilesRules = if githubTokenEnabled then [ "d /var/lib/github 0700 root root -" ] else [];
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # Local AGE key
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Ensure directories exist
  systemd.tmpfiles.rules = githubTmpfilesRules ++ [
    "d /var/lib/sops-nix 0700 root root -"
  ];

  # Root password hash secret used during activation.
  sops.secrets.root_password_hash = {
    sopsFile = ./../secrets/root-password.yaml;
    mode = "0400";
    owner = "root";
    path = "/var/lib/sops-nix/root-password-hash";
  };

  # Shared k3s cluster token used by control plane and workers.
  sops.secrets.k3s_token = {
    sopsFile = ./../secrets/k3s-token.yaml;
    mode = "0400";
    owner = "root";
    path = "/var/lib/rancher/k3s/server/token";
  };

  # Optional GitHub personal access token (used by modules/git.nix).
  sops.secrets.github_token = lib.mkIf githubTokenEnabled {
    sopsFile = githubTokenPath;
    mode = "0400";
    owner = "root";
    path = "/var/lib/github/token";
  };
}
