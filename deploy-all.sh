#!/usr/bin/env bash
set -euo pipefail

# Source list of overlays in the same order the Nix configuration used.
declare -a overlays=(
  "deployments/cert-manager"
  "deployments/metallb"
  "deployments/argocd"
  "deployments/portainer"
  "deployments/victoria"
  # "deployments/gateway-api"

)

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

cd "$(dirname "$0")"

for overlay in "${overlays[@]}"; do
  echo "Applying ${overlay}"
  kustomize build "$overlay" | kubectl apply -f -
done
