# NixOS k3s Cluster Flake

Lightweight NixOS-based k3s cluster for Proxmox VMs. The flake defines one control-plane node plus three workers that share a common module stack (base system, networking, firewall, shared host mappings, k3s bootstrap, Git/SSH identity, and SOPS integration).

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Entry point defining shared modules and all `nixosConfigurations`. |
| `hosts/` | Host templates and the hardware config import. |
| `modules/` | Reusable modules (base, networking, packages, node roles, firewall, `/etc/hosts`, k3s bootstrap, git/ssh, sops, guest agent). |
| `secrets/` | SOPS-encrypted secrets (root password hash, k3s join token). |
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

1. **Hardware config** - Replace `hosts/hardware-configuration.nix` with the `nixos-generate-config` output from the VM you are building.
2. **Age key (shared)** - Generate once, then copy to each host before running any NixOS build or install step:
   ```bash
   install -d -m 700 /var/lib/sops-nix
   age-keygen -o /var/lib/sops-nix/key.txt
   ```
   Every node needs the same key at `/var/lib/sops-nix/key.txt` so SOPS can decrypt secrets during activation.
3. **SOPS policy** - Update `.sops.yaml` with your Age *public* key (`age1...`). This file stays in Git; only the private key lives on hosts.
4. **k3s cluster token** - Run `sops secrets/k3s-token.yaml` and set `k3s_token` to a strong random string (e.g., `openssl rand -hex 32`). Every node reads the token so workers can join automatically.
5. **Root password hash** - Run `sops secrets/root-password.yaml` and set `root_password_hash` to the output of `mkpasswd -m sha-512 'temp-pass'`.
6. **Networking** - Adjust each host's `hostDefs` entry in `flake.nix` (static IP, gateway, nameservers, domain, or `useDHCP`). Shared `/etc/hosts` entries already map the cluster nodes.
7. **SSH key + Git identity** - Replace the placeholder SSH public key and Git identity in `flake.nix`'s `sharedIdentityModule`.

Only after these steps should you proceed to build the system.

## Building a Host

On each VM (booted into the NixOS installer or an existing system):

```bash
git clone <this-repo> /etc/nixos
cd /etc/nixos
nixos-rebuild switch --flake .#k3s-control-1   # or k3s-worker-1 / k3s-worker-2 / k3s-worker-3
```

Replace the flake attribute with the host you are deploying.

## Quickstart (minimal secure path)

1. Generate and copy the Age key to `/var/lib/sops-nix/key.txt` on the target VM.
2. Update `.sops.yaml` with the Age public key.
3. Edit secrets with `sops` (`secrets/root-password.yaml`, `secrets/k3s-token.yaml`).
4. Replace SSH key and Git identity in `flake.nix`.
5. Hardening: set `custom.ssh.enforce = true`, set `custom.ssh.authorizedKeys`, and remove or null `custom.auth.rootPassword`.
6. Deploy a host:
   ```bash
   nixos-rebuild switch --flake .#k3s-control-1
   ```

### First-time install with the default template

Use this when bootstrapping a new VM that should not run k3s yet:

1. Copy your VM's hardware config to `hosts/hardware-configuration.nix`.
2. Ensure `secrets/root-password.yaml`, `secrets/cloudflared-token.yaml`, and `secrets/k3s-token.yaml` are updated via `sops`.
3. Place the shared Age key at `/var/lib/sops-nix/key.txt`.
4. (Optional) Pre-set a static IP by exporting `DEFAULT_STATIC_IPV4`.
5. Run:
   ```bash
   export DEFAULT_STATIC_IPV4=192.168.100.150    # optional
   nixos-install --impure --flake .#default
   ```
   The default host forces `services.k3s.enable = false`, so it never attempts to join the cluster.

## Hardening Guidance

SSH is **not** key-only by default in this repo. The shared identity module enables password auth and permits root login unless you override it. Before deploying, you should:

1. Set `custom.ssh.enforce = true` and provide `custom.ssh.authorizedKeys`.
2. Remove `custom.auth.rootPassword` (or set it to `null`) so the SOPS root hash is required.

If you need per-host overrides (additional users, different keys), extend `custom.ssh` inside the host file.

## Shared Defaults

Each configuration inherits:

- **Base system tweaks** (`modules/base.nix`): kernel params, EFI bootloader, and OpenSSH defaults.
- **Networking** (`modules/networking.nix` + `modules/cluster-hosts.nix`): static IP/DNS/gateway, DHCP toggling, and shared `/etc/hosts` entries for the nodes.
- **Packages** (`modules/packages.nix`): baseline CLI tools (curl, wget, git, vim, htop, jq, yq, sops, etc.).
- **Role detection** (`modules/node-role.nix`): sets `custom.role`, flips k3s between server/agent, and installs kube tooling only on control nodes.
- **k3s bootstrap** (`modules/k3s.nix` + `modules/cluster-bootstrap.nix`): default server/agent flags, join token wiring, and built-in Traefik/ServiceLB disablement on the control plane.
- **Firewall** (`modules/firewall.nix`): role-aware ports for k3s (control-plane: `6443`, `9345`, `2379`, `2380`, `10250`, `8472/udp`; worker: `10250`, `8472/udp`).
- **Git/SSH identity** (inline module in `flake.nix` + `modules/git.nix`/`modules/ssh.nix`): gitconfig and SSH access settings.
- **Guest tooling** (`modules/guest-agent.nix`, `modules/sops.nix`, etc.): qemu guest agent, sops-nix integration, shared packages.

## Operational Notes

- Replace the placeholder SSH public key in `flake.nix` before any deployment. By default, password auth and root login are enabled; set `custom.ssh.enforce = true` to require keys and disable password auth.
- Worker nodes inherit the same secrets as the control plane (k3s token, root password hash).
- If your control-plane endpoint changes, override `custom.cluster.apiServer` inside the worker host file. Otherwise they use the shared host mapping (`https://k3s-control-1:6443`).
- Secrets stay encrypted at rest. After editing with `sops`, commit the ciphertext; the Age private key is only on `/var/lib/sops-nix/key.txt` per host.
- Keep configurations under version control and update `flake.lock` as needed when bumping `nixpkgs` or `sops-nix`.

Treat the repo like production infra: review changes, run `nixos-rebuild switch --flake .#<host>` after each update, and rotate secrets regularly.
