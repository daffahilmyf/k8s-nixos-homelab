{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.custom.git;
  getUserAttr = attr: user: lib.attrByPath ["users" "users" user attr] config null;
  getUserHome = user: let
    home = getUserAttr "home" user;
  in
    if home != null then home else "/home/${user}";
  getUserGroup = user: let
    group = getUserAttr "group" user;
  in
    if group != null then group else user;
  renderGitconfig = user:
    pkgs.writeText "gitconfig-${user}" ''
      [user]
        email = ${cfg.email}
        name = ${cfg.fullName}

      ${lib.optionalString (cfg.passwordFile != null) ''
        [credential]
          helper = "!f() { cat ${cfg.passwordFile}; }; f"
      ''}
    '';
  mkInstallScript = lib.concatStringsSep "\n" (map (user: let
        home = getUserHome user;
        group = getUserGroup user;
        gitconfigFile = renderGitconfig user;
      in ''
        if [ -d "${home}" ]; then
          install -Dm600 ${gitconfigFile} "${home}/.gitconfig"
          chown ${user}:${group} "${home}/.gitconfig"
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
    system.activationScripts.gitconfigs = {
      deps = ["users"];
      text = mkInstallScript;
    };
  };
}
