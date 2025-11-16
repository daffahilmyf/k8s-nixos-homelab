{
  config,
  lib,
  ...
}: {
  services.qemuGuestAgent.enable = lib.mkDefault true;
}
