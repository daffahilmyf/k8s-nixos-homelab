{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.custom.git;
  getUserHome = user: lib.attrByPath ["users" "users" user "home"] config "/home/${user}";
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
    environment.etc = builtins.listToAttrs (map (user: let
        home = getUserHome user;
      in {
        name = "gitconfig-${user}";
        value = {
          mode = "0600";
          target = "${home}/.gitconfig";
          text = ''
            [user]
              email = ${cfg.email}
              name = ${cfg.fullName}

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
