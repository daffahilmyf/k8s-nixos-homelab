{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.custom.git;
  getUserHome = user:
    if user == "root"
    then "/root"
    else "/home/${user}";
  getUserGroup = user:
    if user == "root"
    then "root"
    else user;
  renderGitconfig = user: home:
    pkgs.writeText "gitconfig-${user}" ''
      [user]
        email = ${cfg.email}
        name = ${cfg.fullName}

    '';
  mkInstallScript = lib.concatStringsSep "\n" (map (user: let
        home = getUserHome user;
        group = getUserGroup user;
        gitconfigFile = renderGitconfig user home;
      in ''
        if id "${user}" >/dev/null 2>&1 && [ -d "${home}" ]; then
          install -Dm600 ${gitconfigFile} "${home}/.gitconfig"
          chown ${user}:${group} "${home}/.gitconfig"
        else
          echo "custom.git: skipping ${user} because the account or home directory is missing" >&2
        fi
      '')
      cfg.users);
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

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["root"];
      description = "Users that receive a .gitconfig.";
    };
  };

  # Apply gitconfig when enabled
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = map (user: {
        assertion = lib.hasAttr user config.users.users;
        message = "custom.git.users contains '${user}' but no matching users.users.${user} definition exists.";
      })
      cfg.users;

      system.activationScripts.gitconfigs = {
        deps = ["users"];
        text = mkInstallScript;
      };
    })
  ];
}
