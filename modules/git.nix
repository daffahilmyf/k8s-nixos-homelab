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
  credentialBlock = home:
    let
      includeHelper = cfg.passwordFile != null;
      includeUsername = (cfg.username or "") != "";
    in
      lib.optionalString (includeHelper || includeUsername) ''
        [credential]
          ${lib.optionalString includeHelper "helper = store --file ${home}/.git-credentials"}
          ${lib.optionalString includeUsername "username = ${cfg.username}"}
      '';
  renderGitconfig = user: home:
    pkgs.writeText "gitconfig-${user}" ''
      [user]
        email = ${cfg.email}
        name = ${cfg.fullName}

      ${credentialBlock home}
    '';
  mkInstallScript = lib.concatStringsSep "\n" (map (user: let
        home = getUserHome user;
        group = getUserGroup user;
        gitconfigFile = renderGitconfig user home;
        passwordCopy =
          lib.optionalString (cfg.passwordFile != null) ''
            install -Dm600 ${cfg.passwordFile} "${home}/.git-credentials"
            chown ${user}:${group} "${home}/.git-credentials"
          '';
      in ''
        if id "${user}" >/dev/null 2>&1 && [ -d "${home}" ]; then
          install -Dm600 ${gitconfigFile} "${home}/.gitconfig"
          chown ${user}:${group} "${home}/.gitconfig"
          ${passwordCopy}
        else
          echo "custom.git: skipping ${user} because the account or home directory is missing" >&2
        fi
      '')
      cfg.users);
  githubTokenPath = lib.attrByPath ["sops" "secrets" "github_token" "path"] config null;
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
  config = lib.mkMerge [
    (lib.mkIf (githubTokenPath != null) {
      custom.git.passwordFile = lib.mkDefault githubTokenPath;
    })

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
