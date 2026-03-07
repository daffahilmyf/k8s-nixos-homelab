{
  hostName,
  staticIPv4,
  role,
  interface,
  prefixLength,
  gateway,
  nameservers,
  domain ? null,
}:
{ lib, ... }:
{
  # Import hardware configuration for this VM.
  imports = [
    ./hardware-configuration.nix
  ];

  # Basic node identity + static network settings.
  # Adjust these to match your Proxmox VM configuration.
  custom.networking = {
    hostName = hostName;
    interface = interface;
    staticIPv4 = staticIPv4;
    prefixLength = prefixLength;
    gateway = gateway;
    nameservers = nameservers;
    domain = domain;
  };

  custom.role = role;

  # Export kubeconfig path so kubectl and other tools can find it.
  environment.variables = lib.mkIf (role == "control-plane") {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
}
