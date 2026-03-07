{
  lib,
  config,
  ...
}:
let
  role = config.custom.role;
  hostName = config.networking.hostName;
  isControl = role == "control-plane";
  isFirst = hostName == config.custom.cluster.firstControl;
  vip = config.custom.cluster.vip;
  vipServer = if vip != null then "https://${vip}:6443" else null;
in {
  options.custom.cluster = {
    vip = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Virtual IP for the k3s control-plane (used for HA).";
    };

    firstControl = lib.mkOption {
      type = lib.types.str;
      default = "k3s-control-1";
      description = "Hostname of the first control-plane node that performs cluster init.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (vip != null) {
      custom.cluster.apiServer = lib.mkDefault vipServer;
    })

    (lib.mkIf isControl {
      services.k3s.clusterInit = lib.mkForce isFirst;

      services.k3s.extraFlags = lib.mkAfter (
        lib.optionals (vip != null) [
          "--tls-san ${vip}"
        ]
        ++ lib.optionals (!isFirst && vip != null) [
          "--server ${vipServer}"
        ]
      );
    })
  ];
}
