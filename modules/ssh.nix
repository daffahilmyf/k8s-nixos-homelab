{ lib, config, ... }:

let
  cfg = config.custom.ssh;
in
{
  options.custom.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public keys pushed into each listed user’s authorized_keys.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "root" ];
      description = "Users that receive the authorized keys.";
    };
  };

  config = lib.mkIf (cfg.authorizedKeys != [ ]) {
    users.users = lib.genAttrs cfg.users (_: {
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    });
  };
}
