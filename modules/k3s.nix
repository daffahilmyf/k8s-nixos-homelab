{lib, ...}: {
  # Default k3s settings
  services.k3s.enable = lib.mkDefault true;
}
