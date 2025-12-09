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
2. **Age key (shared)** – Generate once, then copy to each host:
   ```bash
   install -d -m 700 /var/lib/sops-nix
   age-keygen -o /var/lib/sops-nix/key.txt
   ```
   Keep the private key safe; every node needs the same key at `/var/lib/sops-nix/key.txt` so SOPS can decrypt secrets.
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

### Hardening after the first boot

SSH is key-only by default thanks to the shared identity module. Update `flake.nix` with your real public key before deploying; otherwise you will lock yourself out. If you need per-host overrides (additional users, different keys), extend `custom.ssh` inside the host file.

## Shared Defaults

Each configuration inherits:

- **Base system tweaks** (`modules/base.nix`): kernel params, EFI bootloader, and hardened OpenSSH defaults.
- **Networking** (`modules/networking.nix` + `modules/cluster-hosts.nix`): static IP/DNS/gateway, DHCP toggling, and shared `/etc/hosts` entries for the three nodes.
- **Packages** (`modules/packages.nix`): baseline CLI tools (curl, wget, git, vim, htop, jq, yq, sops, etc.).
- **Role detection** (`modules/node-role.nix`): sets `custom.role`, flips k3s between server/agent, and installs kube tooling only on control nodes.
- **k3s bootstrap** (`modules/k3s.nix` + `modules/cluster-bootstrap.nix`): default server/agent flags, join token wiring, and traefik disablement on the control plane.
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
