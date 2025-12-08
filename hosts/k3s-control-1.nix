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

  # Make the kustomize CLI available locally for control-plane tooling.
  custom.kustomize.enable = true;
  # Apply declarative kustomize overlays (Argo CD + Portainer) after each rebuild.
  custom.kustomizeDeploy.enable = true;
  custom.kustomizeDeploy.overlays = [
    {
      name = "Argo CD";
      path = ./../deployments/argocd;
    }
    {
      name = "Portainer";
      path = ./../deployments/portainer;
    }
    {
      name = "MetalLB";
      path = ./../deployments/metallb;
      waitCommands = [
        "kubectl -n metallb-system wait --for=condition=Available deployment/controller --timeout=120s"
        "kubectl -n metallb-system wait --for=condition=Available daemonset/speaker --timeout=120s"
      ];
    }
    {
      name = "Victoria stack";
      path = ./../deployments/victoria;
    }
    {
      name = "cert-manager";
      path = ./../deployments/cert-manager;
    }
    {
      name = "Gateway API";
      path = ./../deployments/gateway-api;
      waitCommands = [
        "kubectl -n projectcontour wait --for=condition=Ready gateway/contour-gateway --timeout=120s"
      ];
    }
  ];
}
