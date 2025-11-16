{
  lib,
  config,
  pkgs,
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

    password = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional PAT or password (plain text).";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["root"];
      description = "Users that receive a .gitconfig.";
    };
  };

  # Apply gitconfig when enabled
  config = lib.mkIf cfg.enable {
    environment.etc = builtins.listToAttrs (map (user: {
        name = "gitconfig-${user}";
        value = {
          mode = "0644";
          target = "/home/${user}/.gitconfig";
          text = ''
            [user]
              email = ${cfg.email}
              name = ${cfg.username}

            ${lib.optionalString (cfg.password != null) ''
              [credential]
                helper = store
                password = ${cfg.password}
            ''}
          '';
        };
      })
      cfg.users);
  };
}
