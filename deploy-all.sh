#!/usr/bin/env bash
set -euo pipefail

# Source list of overlays in the same order the Nix configuration used.
declare -a overlays=(
  "deployments/cert-manager"
  "deployments/metallb"
  "deployments/traefik"
  "deployments/argocd"
  "deployments/portainer"
  "deployments/jenkins"
  "deployments/victoria"
  "deployments/gateway-api"

)

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

cd "$(dirname "$0")"

echo "Installing MetalLB CRDs"
kubectl apply -f deployments/metallb/metallb-crds.yaml

echo "Installing Gateway API CRDs"
kubectl apply -f deployments/gateway-api/standard-install.yaml

echo "Waiting for Gateway API CRDs"
kubectl wait --for=condition=established crd/referencegrants.gateway.networking.k8s.io --timeout=60s

for overlay in "${overlays[@]}"; do
  echo "Applying ${overlay}"
  kustomize build "$overlay" | kubectl apply -f -
done
