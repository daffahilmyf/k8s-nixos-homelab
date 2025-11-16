{
  lib,
  config,
  ...
}: let
  role = config.custom.role;

  controlTcp = [6443 2379 2380 10250];
  controlUdp = [8472];

  workerTcp = [10250];
  workerUdp = [8472];
in {
  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts =
      lib.optionals (role == "control-plane") controlTcp
      ++ lib.optionals (role == "worker") workerTcp;
    allowedUDPPorts =
      lib.optionals (role == "control-plane") controlUdp
      ++ lib.optionals (role == "worker") workerUdp;
  };
}
