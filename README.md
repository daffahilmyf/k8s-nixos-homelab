# NixOS k3s Cluster Flake

Lightweight NixOS-based k3s cluster targeting Proxmox VMs. This flake defines one control-plane and two workers that share a common module stack (packages, networking, k3s, bootstrap helpers, cloudflared, git identity, and sops integration).

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Entry point defining shared modules and three `nixosConfigurations`. |
| `hosts/` | Host-level overrides. Each host imports `hardware-configuration.nix` plus node-specific networking/SSH/git tweaks. |
| `modules/` | Reusable NixOS modules (base system, networking, packages, node roles, k3s defaults, bootstrap helpers, cloudflared, git config, and sops). |
| `secrets/` | SOPS-encrypted or placeholder secrets (root hash, Cloudflare token, k3s join token). |

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
3. **Cloudflare token** – Update `secrets/cloudflared-token.yaml` with the real tunnel token and re-encrypt via `sops secrets/cloudflared-token.yaml`. `modules/cloudflared.nix` deploys it to `/etc/cloudflared/token` and configures the service.
4. **k3s cluster token** – Edit `secrets/k3s-token.yaml` with `sops secrets/k3s-token.yaml` and set `k3s_token` to a strong random string (e.g., `openssl rand -hex 32`). This value is mounted at `/var/lib/rancher/k3s/server/token` on **all** nodes so workers can join without manual file copies.
5. **Networking** – Adjust each host’s `custom.networking` block (hostname, interface name, static IP, prefix length, gateway, nameservers, or `useDHCP`). The defaults assume `ens18` on `192.168.100.0/24`; change them to match your hypervisor.
6. **Git identity (optional)** – Populate `custom.git` values per host if you want `/home/<user>/.gitconfig` files provisioned (control plane enables this by default).
7. **Root password hash** – Edit `secrets/root-password.yaml` with `sops secrets/root-password.yaml` and set `root_password_hash` to the output of `mkpasswd -m sha-512 'your-temp-pass'` (available via `nix shell nixpkgs#whois -c mkpasswd -m sha-512 ...`). Every host consumes this secret during activation.
8. **SSH keys (recommended post-install)** – Prepare the public keys you plan to enforce and add them via `custom.ssh.authorizedKeys`; once you are ready to disable passwords, set `custom.ssh.enforce = true`.

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
   nixos-install --flake .#default
   ```
   This enables SSH with password login for initial access; harden it post-install.

### Hardening after the first boot

Once you log in the first time:

1. Add your SSH public keys to the host configuration:
   ```nix
   custom.ssh = {
     users = [ "root" ];
     authorizedKeys = [
       "ssh-ed25519 AAAAC3Nz... your@laptop"
     ];
     enforce = true; # flips SSH to key-only auth
   };
   ```
2. Rebuild (`nixos-rebuild switch --flake .#<host>`) so future logins require keys and password authentication is disabled automatically.

Each configuration inherits:

- Base system tweaks (`modules/base.nix`): kernel params, EFI bootloader, SSH defaults.
- Networking (`modules/networking.nix`): static IP/DNS/gateway, firewall disabled by default.
- Packages (`modules/packages.nix`): CLI tools, kubectl/helm/k9s, cloudflared, sops.
- Node role detection (`modules/node-role.nix`): sets `services.k3s.role` and adds control-plane tooling.
- k3s defaults (`modules/k3s.nix`) plus bootstrap helpers (`modules/cluster-bootstrap.nix`) to copy tokens to workers.
- Cloudflare tunnel service (`modules/cloudflared.nix`) using the SOPS secret.
- Git identity module (`modules/git.nix`) when `custom.git.enable = true`.

## Operational Notes

- The base module reads the hashed root password from `secrets/root-password.yaml`; host files still enable password auth/root login for bootstrap convenience, so tighten those settings (keys-only auth, disable root login, enable firewall) once the cluster stabilizes.
- Worker nodes inherit SSH enablement from the base module; once `custom.ssh.enforce = true`, password auth and root-password logins are disabled globally.
- Workers point to `https://k3s-control-1:6443` by default; override `custom.cluster.apiServer` in any host file if your control-plane endpoint differs.
- The k3s token now comes from `secrets/k3s-token.yaml`, so there’s no password-based `scp` during bootstrap. Update the secret when rotating cluster credentials.
- The default host template reads `DEFAULT_STATIC_IPV4` so you can inject the installer’s IP without editing files; the root password hash comes from `secrets/root-password.yaml`, and SSH keys are pushed via `custom.ssh.authorizedKeys`.

Keep configurations under version control and update `flake.lock` as needed when bumping `nixpkgs` or `sops-nix`.
