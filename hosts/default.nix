{lib, ...}: let
  # Allow DEFAULT_STATIC_IPV4 env var (exported before nixos-install) to
  # pre-fill the static IP without editing the file.
  envIPv4 = builtins.getEnv "DEFAULT_STATIC_IPV4";

  staticIPv4 =
    if envIPv4 != ""
    then envIPv4
    else null;
in {
  # Generic host template without k3s services.
  imports = [
    ./hardware-configuration.nix
  ];

  # Default build must never start k3s; force it off explicitly.
  services.k3s.enable = lib.mkForce false;

  custom.networking = {
    hostName = "nixos-default";
    interface = "ens18";
    inherit staticIPv4;
    prefixLength = 24;
    gateway = "192.168.100.1";
    nameservers = ["1.1.1.1" "8.8.8.8"];
  };

  custom.role = "worker";

}
