{
  pkgs,
  lib,
  ...
}: {
  # Default tools
  environment.systemPackages = lib.mkDefault (with pkgs; [
    curl
    wget
    git
    vim
    htop
    btop
    jq
    yq
    sops
    kubectl
    kubernetes-helm
    k9s
    cloudflared
  ]);

  # Reduce paging for CLI tools
  environment.variables = {
    HELM_PAGER = "cat";
    PAGER = "cat";
  };
}
