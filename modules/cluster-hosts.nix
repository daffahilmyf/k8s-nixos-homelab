{...}: {
  # Ensure every host in the flake can resolve the cluster nodes locally.
  networking.hosts = {
    "192.168.100.160" = [
      "k3s-control-1"
      "k3s-control-1.home.arpa"
    ];
    "192.168.100.161" = [
      "k3s-worker-1"
      "k3s-worker-1.home.arpa"
    ];
    "192.168.100.162" = [
      "k3s-worker-2"
      "k3s-worker-2.home.arpa"
    ];
  };
}
