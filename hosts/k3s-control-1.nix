{...}: {
  # Import hardware configuration for this VM.
  imports = [
    ./hardware-configuration.nix
  ];

  # Basic host configuration – hostname + static address.
  # These values should match your VM's actual network settings.
  custom.networking = {
    hostName = "k3s-control-1";
    interface = "ens18";
    staticIPv4 = "192.168.100.160";
    prefixLength = 24;
    gateway = "192.168.100.1";
    nameservers = ["1.1.1.1" "8.8.8.8"];
  };
  custom.role = "control-plane";

  # Export kubeconfig path so kubectl and other tools can find it.
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
}
