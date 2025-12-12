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

  custom.cilium = {
    enable = true;
  };

  # Export kubeconfig path so kubectl and other tools can find it.
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  custom.kustomizeDeploy = {
    enable = false;
    overlays = [
      { name = "cert-manager";     path = ../deployments/cert-manager; }
      { name = "metallb";          path = ../deployments/metallb; }
      { name = "gateway-api";       path = ../deployments/gateway-api; }
      { name = "argocd";            path = ../deployments/argocd; }
      { name = "portainer";         path = ../deployments/portainer; }
      { name = "victoria";          path = ../deployments/victoria; }
    ];
  };
}
