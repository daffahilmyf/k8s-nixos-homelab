{...}: {
  # Ensure every host in the flake can resolve the cluster nodes locally.
  networking.hosts = {
    "192.168.100.150" = [
      "k3s-control-1"
      "k3s-control-1.home.arpa"
    ];
    "192.168.100.151" = [
      "k3s-worker-1"
      "k3s-worker-1.home.arpa"
    ];
    "192.168.100.152" = [
      "k3s-worker-2"
      "k3s-worker-2.home.arpa"
    ];
    "192.168.100.153" = [
      "k3s-worker-3"
      "k3s-worker-3.home.arpa"
    ];
  };
}
