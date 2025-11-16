{...}: {
  # Import hardware configuration for this VM.
  imports = [
    ./hardware-configuration.nix
  ];

  # Basic host configuration – hostname + static address.
  # These values should match your VM's actual network settings.
  custom.networking = {
    hostName = "k3s-control-1";
    interface = "ens18";
    staticIPv4 = "192.168.100.160";
    prefixLength = 24;
    gateway = "192.168.100.1";
    nameservers = ["1.1.1.1" "8.8.8.8"];
  };

  # Git identity used for commits inside the system.
  # Replace with your real information.
  custom.git = {
    enable = true;
    email = "your_email@example.com";
    username = "your_username";
    fullName = "Your Name";
  };

  # SSH configuration
  #
  # PermitRootLogin "yes" and PasswordAuthentication = true
  # are convenient for initial setup, but **not recommended** long-term.
  # Switch to key-based auth and disable root login once the system is stable.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes"; # temporary: allows root logins
      PasswordAuthentication = true; # temporary: allows password auth
      # After enabling keys above, switch to:
      # PermitRootLogin = "prohibit-password";
      # PasswordAuthentication = false;
    };
  };

  # SSH public keys (enable post-install once ready).
  # custom.ssh = {
  #   users = [ "root" ];
  #   authorizedKeys = [
  #     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMoExampleKeyHere user@example"
  #   ];
  # };

  # Export kubeconfig path so kubectl and other tools can find it.
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
}
