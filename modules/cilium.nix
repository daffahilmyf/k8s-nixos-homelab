{
  lib,
  ...
}: {
  options.custom.cilium = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description =
        "When true, the cluster launches Cilium (replace kube-proxy) and expects the\n"
        "accompanying network manifest applied via deployments/cilium.";
    };
  };
}
