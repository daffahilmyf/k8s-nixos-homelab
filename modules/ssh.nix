{
  lib,
  config,
  ...
}:
let
  cfg = config.custom.ssh;
in {
  options.custom.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Public keys pushed into each listed user’s authorized_keys.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["root"];
      description = "Users that receive the authorized keys.";
    };

    enforce = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, disable password auth/root login (requires authorizedKeys).";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.authorizedKeys != []) {
      users.users = lib.genAttrs cfg.users (_: {
        openssh.authorizedKeys.keys = cfg.authorizedKeys;
      });
    })

    (lib.mkIf cfg.enforce {
      assertions = [
        {
          assertion = cfg.authorizedKeys != [];
          message = "custom.ssh.enforce requires custom.ssh.authorizedKeys to be non-empty.";
        }
      ];

      services.openssh.settings = {
        PermitRootLogin = lib.mkForce "prohibit-password";
        PasswordAuthentication = lib.mkForce false;
      };
    })
  ];
}
