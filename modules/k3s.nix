{lib, ...}: {
  # Default k3s settings
  services.k3s = {
    enable = lib.mkDefault true;

    extraFlags = lib.mkDefault ''
      --disable traefik
    '';
  };
}
