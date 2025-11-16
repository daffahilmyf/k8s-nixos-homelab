{ lib, ... }:

let
  # Allow DEFAULT_STATIC_IPV4 env var (exported before nixos-install) to
  # pre-fill the static IP without editing the file.
  envIPv4 = builtins.getEnv "DEFAULT_STATIC_IPV4";

  staticIPv4 = if envIPv4 != "" then envIPv4 else null;
in
{
  # Generic host template without k3s services.
  imports = [
    ./hardware-configuration.nix
  ];

  custom.networking = {
    hostName = "nixos-default";
    inherit staticIPv4;
  };

  # Disable k3s and related bootstrap helpers for standalone hosts.
  services.k3s.enable = false;
  systemd.services.k3s-bootstrap-token.enable = false;
  systemd.services.k3s-fetch-token.enable = false;

  # Enable SSH with password + root login for initial bootstrap (harden later).
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      # After enabling keys above, switch to stricter settings:
      # PermitRootLogin = "prohibit-password";
      # PasswordAuthentication = false;
    };
  };

  # SSH public keys (enable post-install to harden access).
  # custom.ssh = {
  #   users = [ "root" ];
  #   authorizedKeys = [
  #     "ssh-ed25519 AAAAC3NzaC1exampleKeyGoesHere installer@example"
  #   ];
  # };
}
