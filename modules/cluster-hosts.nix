{...}: {
  # Ensure every host in the flake can resolve the cluster nodes locally.
  networking.hosts = {
    "192.168.100.150" = [
      "k3s-control-1"
      "k3s-control-1.home.arpa"
    ];
    "192.168.100.155" = [
      "k3s-control-2"
      "k3s-control-2.home.arpa"
    ];
    "192.168.100.156" = [
      "k3s-control-3"
      "k3s-control-3.home.arpa"
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
    "192.168.100.154" = [
      "k3s-control-vip"
      "k3s-control-vip.home.arpa"
    ];
  };
}
