{
  lib,
  config,
  ...
}: let
  cfg = config.custom.git;
in {
  # Git module options
  options.custom.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Git global configuration.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      description = "Git user email.";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      description = "Git full name.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      description = "Git username.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to a secret file that holds a Git PAT/password (e.g. config.sops.secrets.<name>.path).";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["root"];
      description = "Users that receive a .gitconfig.";
    };
  };

  # Apply gitconfig when enabled
  config = lib.mkIf cfg.enable {
    users.users = lib.genAttrs cfg.users (_: {
      files.".gitconfig" = {
        mode = "0600";
        text = ''
          [user]
            email = ${cfg.email}
            name = ${cfg.fullName}

          ${lib.optionalString (cfg.passwordFile != null) ''
            [credential]
              helper = "!f() { cat ${cfg.passwordFile}; }; f"
          ''}
        '';
      };
    });
  };
}
