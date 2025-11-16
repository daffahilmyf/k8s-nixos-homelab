{
  config,
  lib,
  ...
}: {
  services.qemuGuest.enable = lib.mkDefault true;
}
