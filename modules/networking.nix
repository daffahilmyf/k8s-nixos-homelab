{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.networking;
in {
  # Networking options
  options.custom.networking = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "default-host";
      description = "System hostname.";
    };

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "ens18";
      description = "Primary network interface name.";
    };

    staticIPv4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Static IPv4 address (set to null to use DHCP).";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Subnet prefix length for the static IPv4 address.";
    };

    gateway = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "192.168.100.1";
      description = "Default gateway (null disables the route).";
    };

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "home.arpa";
      description = "DNS domain appended to the hostname (null disables).";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["1.1.1.1" "8.8.8.8"];
      description = "Resolver list applied via resolvconf.";
    };

    useDHCP = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Whether to enable DHCP on the primary interface (default: true when no static IPv4 is set).";
    };
  };

  # Apply settings
  config = {
    networking = {
      hostName = cfg.hostName;
      domain = lib.mkIf (cfg.domain != null) cfg.domain;
      search = lib.mkIf (cfg.domain != null) [cfg.domain];
      firewall.enable = lib.mkDefault false;
      useDHCP = lib.mkForce (if cfg.useDHCP == null then cfg.staticIPv4 == null else cfg.useDHCP);
      nameservers = lib.mkDefault cfg.nameservers;
      defaultGateway = lib.mkIf (cfg.gateway != null) cfg.gateway;

      interfaces =
        lib.mkIf (cfg.interface != null) {
          "${cfg.interface}" =
            {
              useDHCP = if cfg.useDHCP == null then cfg.staticIPv4 == null else cfg.useDHCP;
            }
            // lib.optionalAttrs (cfg.staticIPv4 != null) {
              useDHCP = false;
              ipv4.addresses = [
                {
                  address = cfg.staticIPv4;
                  prefixLength = cfg.prefixLength;
                }
              ];
            };
        };
    };
  };
}
