{
  config,
  lib,
  ...
}: let
  hasQemuGuestOption = lib.hasAttrByPath ["services" "qemuGuestAgent"] config;
in {
  config = lib.mkIf hasQemuGuestOption {
    services.qemuGuestAgent.enable = lib.mkDefault true;
  };
}
