# NixOS k3s Cluster Flake

Lightweight NixOS-based k3s cluster targeting Proxmox VMs. The flake defines one control-plane node plus two workers that share a hardened module stack (base system, networking, firewall, shared host mappings, k3s bootstrap helpers, Git/SSH identity, and SOPS integration).

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Entry point defining shared modules and all `nixosConfigurations`. |
| `hosts/` | Host-level overrides (hardware config import + networking tweaks). |
| `modules/` | Reusable modules (base, networking, packages, node roles, firewall, `/etc/hosts`, k3s bootstrap, cloudflared, git/ssh, sops, guest agent). |
| `secrets/` | SOPS-encrypted secrets (root password hash, Cloudflare token, k3s join token). |
| `.sops.yaml` | Encryption policy referencing your Age public key. |

## Tooling Needed (installer or dev machine)

Even on the minimal NixOS installer you can pull in the tools required for secrets work:

```bash
# Spawn a shell that has git, sops, age, and mkpasswd (from whois)
nix shell nixpkgs#git nixpkgs#sops nixpkgs#age nixpkgs#whois
```

Stay inside that shell while cloning the repo, generating keys, and editing secrets.

## Prerequisites

Do **not** run `nixos-rebuild` until every prerequisite is satisfied:

1. **Hardware config** – Replace `hosts/hardware-configuration.nix` with the `nixos-generate-config` output from the VM you are building. Without this the system cannot boot.
2. **Age key (shared)** – Generate once, then copy to each host before running any NixOS build/installation step:
   ```bash
   install -d -m 700 /var/lib/sops-nix
   age-keygen -o /var/lib/sops-nix/key.txt
   ```
   Keep the private key safe; every node needs the same key at `/var/lib/sops-nix/key.txt` so SOPS can decrypt secrets. The installer runs `sops-install-secrets` during activation, so `/var/lib/sops-nix/key.txt` must already exist on the target filesystem when `nixos-install` or `nixos-rebuild` runs.
3. **SOPS policy** – Update `.sops.yaml` with your Age *public* key (`age1...`). This file stays in Git; only the private key lives on hosts.
4. **Cloudflare token** – Run `sops secrets/cloudflared-token.yaml` and set `cloudflared_token` to the real tunnel token. Only the control plane consumes this secret.
5. **k3s cluster token** – Run `sops secrets/k3s-token.yaml` and set `k3s_token` to a strong random string (e.g., `openssl rand -hex 32`). Every node reads the token file so workers can join automatically.
6. **Root password hash** – Run `sops secrets/root-password.yaml` and set `root_password_hash` to the output of `mkpasswd -m sha-512 'temp-pass'`.
7. **Networking** – Adjust each host’s `custom.networking` block (hostname, interface, static IP, prefix length, gateway, optional domain, nameservers, or `useDHCP`). Shared `/etc/hosts` entries already map the three cluster nodes.
8. **SSH key + Git identity** – Replace the placeholder SSH public key and Git identity defined in `flake.nix`’s inline `sharedIdentityModule`. All hosts inherit those defaults, so set them once before deploying.

Only after these steps should you proceed to build the system.

## Building a Host

On each VM (booted into the NixOS installer or an existing system):

```bash
git clone <this-repo> /etc/nixos
cd /etc/nixos
nixos-rebuild switch --flake .#k3s-control-1   # or k3s-worker-1 / k3s-worker-2
```

Replace the flake attribute with the host you are deploying. For first installs, you can use the generic `hosts/default.nix` template and pre-fill the static IP by exporting `DEFAULT_STATIC_IPV4` before running `nixos-install`, e.g.:

### First-time install with the default template

Use this when bootstrapping a new VM that shouldn’t run k3s yet:

1. Copy your VM’s hardware config to `hosts/hardware-configuration.nix`.
2. Ensure `secrets/root-password.yaml`, `secrets/cloudflared-token.yaml`, and `secrets/k3s-token.yaml` are updated via `sops`.
3. Place the shared Age key at `/var/lib/sops-nix/key.txt` (see prerequisites).
4. (Optional) Pre-set a static IP by exporting `DEFAULT_STATIC_IPV4`.
5. Run:
   ```bash
   export DEFAULT_STATIC_IPV4=192.168.100.150    # optional
   nixos-install --impure --flake .#default
   ```
   The default host forces `services.k3s.enable = false`, so it never attempts to join the cluster.
   **Prep:** copy `/var/lib/sops-nix/key.txt` into the installer environment before invoking `nixos-install` so the `setupSecrets` activation snippet can decrypt the secrets bundle.

### Hardening after the first boot

SSH is key-only by default thanks to the shared identity module. Update `flake.nix` with your real public key before deploying; otherwise you will lock yourself out. If you need per-host overrides (additional users, different keys), extend `custom.ssh` inside the host file.

## Shared Defaults

Each configuration inherits:

- **Base system tweaks** (`modules/base.nix`): kernel params, EFI bootloader, and hardened OpenSSH defaults.
- **Networking** (`modules/networking.nix` + `modules/cluster-hosts.nix`): static IP/DNS/gateway, DHCP toggling, and shared `/etc/hosts` entries for the three nodes.
- **Packages** (`modules/packages.nix`): baseline CLI tools (curl, wget, git, vim, htop, jq, yq, sops, etc.).
- **Role detection** (`modules/node-role.nix`): sets `custom.role`, flips k3s between server/agent, and installs kube tooling only on control nodes.
- **k3s bootstrap** (`modules/k3s.nix` + `modules/cluster-bootstrap.nix`): default server/agent flags, join token wiring, and built-in Traefik/ServiceLB disablement on the control plane so you can install a Gateway-capable Traefik from the overlay stack.
- **Firewall** (`modules/firewall.nix`): enables the firewall with role-aware allowed ports (API/etcd on the control plane, kubelet/VXLAN on workers).
- **Cloudflare tunnel** (`modules/cloudflared.nix`): only included on `k3s-control-1` so workers stay lean.
- **Git/SSH identity** (inline module in `flake.nix` + `modules/git.nix`/`modules/ssh.nix`): consistent gitconfig and enforced SSH key auth.
- **Guest tooling** (`modules/guest-agent.nix`, `modules/sops.nix`, etc.): qemu guest agent, sops-nix integration, shared packages.

## Operational Notes

- Replace the placeholder SSH public key in `flake.nix` before any deployment. The shared module enforces key-only SSH for `root`, so a missing key means no access.
- Worker nodes inherit the same secrets as the control plane (k3s token, root password hash) but do **not** run cloudflared. Their firewall only opens kubelet/VXLAN ports.
- If your control-plane endpoint changes, override `custom.cluster.apiServer` inside the worker host file. Otherwise they use the shared host mapping (`https://k3s-control-1:6443`).
- Secrets stay encrypted at rest. After editing with `sops`, commit the ciphertext; the Age private key is only on `/var/lib/sops-nix/key.txt` per host.
- Keep configurations under version control and update `flake.lock` as needed when bumping `nixpkgs` or `sops-nix`.

Treat the repo like production infra: code review changes, run `nixos-rebuild switch --flake .#<host>` after each update, and rotate secrets regularly.

## Cilium dataplane

- The new `deployments/cilium` overlay pulls the Cilium `v1.15.3` manifest and patches `cilium-config` to enforce strict kube-proxy replacement, BPF masquerading, VXLAN tunneling, and the auto-direct route optimisations introduced for hardening.
- Every host now sets `custom.cilium.enable = true` (see `hosts/k3s-control-1.nix` and the two workers), which lets `modules/cluster-bootstrap.nix` append `--disable kube-proxy` to `services.k3s.extraFlags`; this keeps the upstream proxy from racing with Cilium.
- Apply the overlay as part of `./deploy-all.sh` (it runs first) or manually with `kubectl apply -k deployments/cilium` once the control plane is healthy.

## Traefik Gateway overlay

- The `deployments/traefik` overlay now deploys Traefik v2 with `--providers.kubernetesgateway`, exposes ports 80/443 via MetalLB at `192.168.100.220`, and grants it RBAC to watch Gateway API resources.
- Since the control plane disables the bundled Traefik (`modules/cluster-bootstrap.nix`), the overlay provides the single instance that accepts `Gateway`/`HTTPRoute` attachments, making the `deployments/gateway-api` overlay functional.

## Jenkins overlay

- The `deployments/jenkins` overlay provisions a `jenkins` namespace with a PVC-backed `jenkins` Deployment and ClusterIP service. The Deployment mounts `/var/jenkins_home` from a 5 Gi `PersistentVolumeClaim` using the `generic` storage class and runs the official `jenkins/jenkins:lts` image with basic readiness/liveness probes.
- `deployments/gateway-api/httproute-jenkins.yaml` attaches the Jenkins Service to the Traefik Gateway via `jenkins.tesutotech.my.id`, so Cloudflare Tunnel (or another DNS) must resolve that hostname to `192.168.100.220` and preserve the original `Host` header when proxying HTTPS traffic.
- Apply the overlay with `kustomize build deployments/jenkins | kubectl apply -f -` (or re-run `./deploy-all.sh` now that Jenkins is added to the overlay list) to bring Jenkins online; the HTTPRoute will then allow Traefik to route browser traffic to Jenkins's web UI.

### Kubernetes-based agent autoscaling

- Jenkins ships with a Kubernetes plugin that provisions worker pods on demand. With the above overlay, you already have:
  * a dedicated `jenkins` ServiceAccount plus ClusterRole/Binding (`deployments/jenkins/jenkins-serviceaccount.yaml`, `jenkins-clusterrole.yaml`, `jenkins-clusterrolebinding.yaml`),
  * the permissions to create pods, secrets, configmaps, services, and jobs required by the plugin.
- Configure the Jenkins Kubernetes cloud by keeping `Kubernetes URL` blank (so it uses the in-cluster API) and pointing `Kubernetes Namespace` to `jenkins`. Create a Jenkins credential of type **Secret Text** that holds the service account token:
  ```
  token=$(kubectl -n jenkins get secret $(kubectl -n jenkins get sa jenkins -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode)
  ```
  Store that `token` as a Jenkins credential (ID `k3s-jenkins`) and select it when configuring the cloud.
- Add a Pod Template inside the cloud:
  * Label: `k8s-agent`
  * Containers: use `jenkins/inbound-agent:lts` with args `$(JENKINS_SECRET) $(JENKINS_NAME)`
  * Resource requests/limits tuned for your workers (e.g., `500m` CPU, `1Gi` memory per agent).
* Set the template's **Usage** to "Use this node as much as possible" so agents stay idle rather than blocking builds.
- When you configure your pipelines or freestyle jobs, target the label `k8s-agent`; Jenkins will then create pods on the worker nodes as needed, keeping the control node (and Jenkins master) relatively light.

## Resource posture

- Every deployment in this repo runs on low-resource hardware, so tighten CPU/memory requests and limits inside each overlay to the smallest values that still allow your CI jobs to finish. The Jenkins overlay already exposes the agent resource knobs inside the Kubernetes cloud (see `README.md:121-134`), but you can also add `resources.requests` / `resources.limits` blocks to the Traefik, Argocd, Portainer, Victoria, Metallb, and Gateway manifests if you need to force strict packing.
- Traefik, Portainer, the Argo CD server, Victoria Metrics, and the Jenkins master all now define conservative requests/limits so they run comfortably on your control-plane VM while the workers tackle the heavy builds (`deployments/traefik/traefik-resources.yaml`, `deployments/portainer/portainer-resources.yaml`, `deployments/argocd/argocd-server-resources.yaml`, `deployments/victoria/victoria-resources.yaml`, `deployments/jenkins/jenkins-resources.yaml`). Argo CD now asks for 1 CPU / 1 GiB (with a 1.5 CPU/1.5 GiB ceiling), Jenkins now requests 1 CPU and 1.5 GiB (with a 2 CPU/2 GiB ceiling), and you can adjust the other patches upward only if you see actual contention.
- On k3s itself you can enforce a default `LimitRange` for the `jenkins`, `portainer`, and `argocd` namespaces that caps CPU/memory per pod further. Apply something like:
  ```
  apiVersion: v1
  kind: LimitRange
  metadata:
    name: namespace-limits
    namespace: jenkins
  spec:
    limits:
      - type: Container
        defaultRequest:
          cpu: 100m
          memory: 128Mi
        default:
          cpu: 200m
          memory: 256Mi
  ```
  Adjust each namespace’s limits according to the workload. This keeps the control-plane pods light while still letting you run occasional heavier tasks on the workers.
