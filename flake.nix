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
    hostDefs = {
      k3s-control-1 = {
        staticIPv4 = "192.168.100.150";
        role = "control-plane";
        enableKustomize = true;
      };
      k3s-worker-1 = {
        staticIPv4 = "192.168.100.151";
        role = "worker";
      };
      k3s-worker-2 = {
        staticIPv4 = "192.168.100.152";
        role = "worker";
      };
      k3s-worker-3 = {
        staticIPv4 = "192.168.100.153";
        role = "worker";
        networking = {
          # Example per-host override
          nameservers = ["1.1.1.1" "9.9.9.9"];
        };
      };
    };

    clusterNetworkingDefaults = {
      interface = "ens18";
      prefixLength = 24;
      gateway = "192.168.100.1";
      nameservers = ["1.1.1.1" "8.8.8.8"];
      domain = "home.arpa";
    };

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
    nixosConfigurations =
      (nixpkgs.lib.mapAttrs (hostName: def:
        let
          hostNet = clusterNetworkingDefaults // (def.networking or {});
        in nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          # Pass flake inputs to modules (required for sops)
          specialArgs = {inherit inputs;};

          modules =
            sharedModules
            ++ [
              (import ./hosts/host-template.nix {
                hostName = hostName;
                staticIPv4 = def.staticIPv4;
                role = def.role;
                enableKustomize = def.enableKustomize or false;
                interface = hostNet.interface;
                prefixLength = hostNet.prefixLength;
                gateway = hostNet.gateway;
                nameservers = hostNet.nameservers;
                domain = hostNet.domain or null;
              })
            ]
            ;
        })
        hostDefs)
      // {
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
