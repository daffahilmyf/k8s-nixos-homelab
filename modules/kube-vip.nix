{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.kubeVip;
  role = config.custom.role;
  isControl = role == "control-plane";
  manifestPath = "/var/lib/rancher/k3s/server/manifests/kube-vip.yaml";
  manifestText = ''
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: kube-vip
      namespace: kube-system
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: kube-vip
    rules:
      - apiGroups: [""]
        resources: ["services", "services/status", "endpoints"]
        verbs: ["get", "list", "watch", "update"]
      - apiGroups: [""]
        resources: ["nodes"]
        verbs: ["list", "watch", "get"]
      - apiGroups: ["coordination.k8s.io"]
        resources: ["leases"]
        verbs: ["get", "list", "watch", "update", "create"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: kube-vip
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: kube-vip
    subjects:
      - kind: ServiceAccount
        name: kube-vip
        namespace: kube-system
    ---
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: kube-vip
      namespace: kube-system
      labels:
        app: kube-vip
    spec:
      selector:
        matchLabels:
          app: kube-vip
      template:
        metadata:
          labels:
            app: kube-vip
        spec:
          serviceAccountName: kube-vip
          hostNetwork: true
          containers:
            - name: kube-vip
              image: ${cfg.image}
              imagePullPolicy: IfNotPresent
              args: ["manager"]
              env:
                - name: vip_interface
                  value: "${cfg.interface}"
                - name: vip_address
                  value: "${cfg.vip}"
                - name: vip_arp
                  value: "true"
                - name: vip_leaderelection
                  value: "true"
                - name: vip_leaderelection_namespace
                  value: "kube-system"
                - name: cp_enable
                  value: "true"
                - name: svc_enable
                  value: "false"
              securityContext:
                capabilities:
                  add:
                    - NET_ADMIN
                    - NET_RAW
          tolerations:
            - key: "node-role.kubernetes.io/control-plane"
              operator: "Exists"
              effect: "NoSchedule"
            - key: "node-role.kubernetes.io/master"
              operator: "Exists"
              effect: "NoSchedule"
  '';
in {
  options.custom.kubeVip = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Deploy kube-vip to provide a control-plane virtual IP.";
    };

    vip = lib.mkOption {
      type = lib.types.str;
      description = "Virtual IP address for the control plane.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "ens18";
      description = "Network interface for kube-vip ARP announcements.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/kube-vip/kube-vip:v0.7.2";
      description = "kube-vip container image.";
    };
  };

  config = lib.mkIf (cfg.enable && isControl) {
    assertions = [
      {
        assertion = cfg.vip != "";
        message = "custom.kubeVip.vip must be set when kube-vip is enabled.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/rancher/k3s/server/manifests 0700 root root -"
    ];

    system.activationScripts.kubeVipManifest = {
      deps = ["users"];
      text = ''
        install -Dm600 /dev/null "${manifestPath}"
        cat > "${manifestPath}" <<'EOF'
${manifestText}
EOF
      '';
    };
  };
}
