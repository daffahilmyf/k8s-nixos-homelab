{
  config,
  lib,
  ...
}: let
  cfg = config.custom.networking;
in {
  # Networking options
  options.custom.networking = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "default-host";
    };

    staticIPv4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  # Apply settings
  config = {
    networking = {
      hostName = cfg.hostName;
      firewall.enable = lib.mkDefault false;
      useDHCP = lib.mkForce false;

      interfaces.ens18.ipv4.addresses = lib.mkIf (cfg.staticIPv4 != null) [
        {
          address = cfg.staticIPv4;
          prefixLength = 24;
        }
      ];

      nameservers = lib.mkDefault ["1.1.1.1" "8.8.8.8"];
      defaultGateway = lib.mkDefault "192.168.100.1";
    };
  };
}
