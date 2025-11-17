{
  lib,
  config,
  ...
}:
let
  isControl = config.custom.role == "control-plane";
  isWorker = config.custom.role == "worker";
  tokenPath = config.sops.secrets.k3s_token.path;
  sopsServiceName = "sops-nix";
  hasSopsService = builtins.hasAttr sopsServiceName config.systemd.services;
  sopsDeps = lib.optionals hasSopsService ["${sopsServiceName}.service"];
in {
  options.custom.cluster.apiServer = lib.mkOption {
    type = lib.types.str;
    default = "https://k3s-control-1:6443";
    description = "k3s API endpoint workers use to join the cluster.";
  };

  config = {
    assertions = [
      {
        assertion = tokenPath != null;
        message = "k3s token secret (secrets/k3s-token.yaml) must be configured.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/rancher/k3s/server 0700 root root -"
    ];

    services.k3s.tokenFile = tokenPath;

    services.k3s.extraFlags = lib.concatStringsSep "\n" (
      lib.optional isControl "--disable traefik"
      ++ lib.optional isControl "--token-file ${tokenPath}"
      ++ lib.optional isWorker ''
        --server ${config.custom.cluster.apiServer}
        --token-file ${tokenPath}
      ''
    );

    systemd.services.k3s = {
      wants = ["network-online.target"] ++ sopsDeps;
      after = ["network-online.target"] ++ sopsDeps;
      requires = sopsDeps;
    };
  };
}
