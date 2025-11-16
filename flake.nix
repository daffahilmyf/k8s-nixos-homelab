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
    baseModules = [
      ./modules/base.nix
      ./modules/networking.nix
      ./modules/packages.nix
      ./modules/sops.nix
      ./modules/cloudflared.nix
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
