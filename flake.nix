{
  description = "Lightweight industrial k3s NixOS cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = {
    self,
    nixpkgs,
    sops-nix,
  } @ inputs: let
    sharedIdentityModule = {
      lib,
      config,
      ...
    }: {
      custom.auth.rootPassword = lib.mkDefault "root";

      custom.git = {
        enable = lib.mkDefault true;
        email = lib.mkDefault "daffahilmanafrizal@gmail.com";
        fullName = lib.mkDefault "Daffa Hilmy Fadhlurrohman";
      };

      custom.ssh = {
        users = lib.mkDefault ["root"];
        authorizedKeys = lib.mkDefault [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBFnUyRhULGR1yGE1BseKum7xPxWBlo8JcEP39qVnGm9 daffahilmanafrizal@gmail.com"
        ];
        enforce = lib.mkDefault false;
        passwordAuthentication = lib.mkDefault true;
        permitRootLogin = lib.mkDefault "yes";
      };
    };

    baseModules = [
      sharedIdentityModule
      ./modules/base.nix
      ./modules/networking.nix
      ./modules/packages.nix
      ./modules/sops.nix
      ./modules/git.nix
      ./modules/ssh.nix
      ./modules/firewall.nix
      ./modules/guest-agent.nix
      ./modules/cluster-hosts.nix
    ];

    sharedModules =
      baseModules
      ++ [
        ./modules/k3s.nix
        ./modules/node-role.nix
        ./modules/cluster-bootstrap.nix
      ];
  in {
    nixosConfigurations = {
      k3s-control-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # Pass flake inputs to modules (required for sops)
        specialArgs = {inherit inputs;};

        modules =
          sharedModules
          ++ [
            ./modules/cloudflared.nix
            ./hosts/k3s-control-1.nix
          ];
      };

      k3s-worker-1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {inherit inputs;};

        modules =
          sharedModules
          ++ [
            ./hosts/k3s-worker-1.nix
          ];
      };

      k3s-worker-2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {inherit inputs;};

        modules =
          sharedModules
          ++ [
            ./hosts/k3s-worker-2.nix
          ];
      };

      default = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {inherit inputs;};

        modules =
          baseModules
          ++ [
            ./hosts/default.nix
          ];
      };
    };
  };
}
