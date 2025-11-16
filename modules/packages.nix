{
  pkgs,
  lib,
  ...
}: {
  # Default tools installed on every host
  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    vim
    htop
    btop
    jq
    yq
    sops
  ];

  # Reduce paging for CLI tools
  environment.variables = {
    HELM_PAGER = "cat";
    PAGER = "cat";
  };
}
