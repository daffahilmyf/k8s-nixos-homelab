# NixOS k3s Homelab

Lightweight, production-oriented NixOS flake that declares one control-plane host and two workers, all sharing reusable modules for networking, k3s, secrets, observability, and service delivery (Argo CD, Portainer, MetalLB, Victoria stack, cert-manager, and Contour Gateway API).

## Quick start tools

```bash
# Spawn a shell that includes git, sops, age, and mkpasswd (from whois)
nix shell nixpkgs#git nixpkgs#sops nixpkgs#age nixpkgs#whois
```

Carry out every git/sops change from inside that shell so the helper tools are available.

## Prerequisites (do **not** rebuild until each step is done)

1. **Hardware config** – Replace `hosts/hardware-configuration.nix` with `nixos-generate-config` output from the target VM.
2. **Age key (shared)** – Generate once and copy to every host:
   ```bash
   install -d -m 700 /var/lib/sops-nix
   age-keygen -o /var/lib/sops-nix/key.txt
   ```
3. **SOPS policy** – Update `.sops.yaml` with your Age *public* key (`age1...`). The policy stays in Git; the private key lives on each host.
4. **Cloudflare tunnel** – Enable the tunnel and record the token inside `secrets/cloudflared-token.yaml` via `sops`.
5. **k3s cluster token** – Run `sops secrets/k3s-token.yaml`, set `k3s_token` to a strong random string (e.g., `openssl rand -hex 32`), and commit the ciphertext.
6. **Root password hash** – Run `sops secrets/root-password.yaml` and set `root_password_hash` to `mkpasswd -m sha-512 'temp-pass'`.
7. **Networking** – Update each `custom.networking` block (hostname, interface, static IP/prefix, gateway, domain, nameservers, optional `useDHCP`). `/etc/hosts` entries already map the three cluster nodes.
8. **SSH + Git identity** – Replace the placeholder SSH public key and Git identity defined in the inline `sharedIdentityModule`. Every host inherits those defaults, so populate `custom.ssh.authorizedKeys` (and optionally enable `custom.ssh.enforce`) before deployment—password auth/root login are disabled by default.
9. **GitHub PAT (optional automation)** – Copy `secrets/github-token.yaml.template` → `secrets/github-token.yaml`, edit with `sops secrets/github-token.yaml`, set `github_token` to a scoped PAT, and commit the ciphertext. The Git module will install it for root automatically.

Only after all prerequisites are satisfied should you run `nixos-rebuild`.

## Building a host

```bash
git clone <this-repo> /etc/nixos
cd /etc/nixos
nixos-rebuild switch --flake .#k3s-control-1   # or #k3s-worker-1 / #k3s-worker-2
```

- To bootstrap a fresh VM (without k3s), copy its hardware config into `hosts/hardware-configuration.nix`, set `DEFAULT_STATIC_IPV4` if desired, and run:
  ```bash
  export DEFAULT_STATIC_IPV4=192.168.100.150
  nixos-install --impure --flake .#default
  ```
  The `default` configuration forces `services.k3s.enable = false` so it never joins the cluster.

## Hardening notes

- SSH is key-only by default thanks to the shared identity module. Update `custom.ssh.authorizedKeys` before deploying or you will lock yourself out.
- If you need per-host users or keys, extend `custom.ssh` inside the respective host file.
- `custom.auth.rootPassword` is unset so only the encrypted secret controls the initial root password.

## Shared configuration layers

Every host inherits the following modules and helpers:

- **Base system tweaks** (`modules/base.nix`): kernel params, EFI/systemd-boot, hardened OpenSSH defaults, and enforced root-password assertions.
- **Networking** (`modules/networking.nix` + `modules/cluster-hosts.nix`): static IP vs DHCP flags plus shared `/etc/hosts` entries.
- **Packages** (`modules/packages.nix`): curl, wget, git, vim, htop, btop, jq, yq, sops, etc.
- **Role detection** (`modules/node-role.nix`): each host must set `custom.role` to `control-plane` or `worker`, and control planes get kubectl/helm/k9s.
- **k3s bootstrap** (`modules/k3s.nix` + `modules/cluster-bootstrap.nix`): default server/agent flags, join token wiring, and traefik disablement.
- **Firewall** (`modules/firewall.nix`): open API/etcd ports on the control plane, kubelet/VXLAN on workers.
- **Cloudflare tunnel** (`modules/cloudflared.nix`): only enabled on `k3s-control-1`.
- **Git/SSH identity**: inline `sharedIdentityModule` plus `modules/git.nix`/`modules/ssh.nix` ensure consistent gitconfig/authorized keys.
- **Kustomize tooling** (`modules/kustomize.nix` + local flag): kustomize is installed on the control plane so overlays can run.
- **Kustomize deployments** (`modules/kustomize-deploy.nix`): sequentially applies overlays (Argo CD, Portainer, MetalLB, Victoria stack, cert-manager, Gateway API) and waits for MetalLB/Contour readiness to avoid race conditions.
- **Alerting/observability**: the Victoriametrics/Victoria logs overlay runs under `monitoring`, while MetalLB, cert-manager, and the Gateway API controller run in their own namespaces.
- **GitHub automation** (`secrets/github-token.yaml` + `modules/git.nix`): installs the PAT into `/root/.git-credentials` if you add the secret.

## Operational notes

- `deployments/argocd`, `deployments/portainer`, `deployments/metallb`, `deployments/victoria`, `deployments/cert-manager`, and `deployments/gateway-api` are each applied via `custom.kustomizeDeploy` after every rebuild. Update the overlays and rerun `nixos-rebuild` to refresh the stacks.
- Keep cloudflared pointing at the single MetalLB IP (range `192.168.100.220-230`) so all hostnames (`*.tesutotech.my.id`) ride the same tunnel endpoint. The Gateway API routes (Contour + HTTPRoutes) split traffic by hostname inside the cluster.
- Secrets stay encrypted at rest; after editing with `sops`, commit the ciphertext. The Age private key belongs on each host at `/var/lib/sops-nix/key.txt`.
- Use `kubectl` against `/etc/rancher/k3s/k3s.yaml` (exported via `environment.variables`) or copy it locally for admin tooling.
- Treat this repo like production infra: review changes, rebuild specific hosts with `nixos-rebuild switch --flake .#<host>`, and rotate secrets regularly.

Feel free to extend overlays, add new Gateway routes, or plug in additional tooling when the need arises. Let me know if you want help wiring another overlay or simplifying any part of the flow.
