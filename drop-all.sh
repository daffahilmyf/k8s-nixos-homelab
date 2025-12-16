#!/usr/bin/env bash
set -euo pipefail

# Drop the same overlays as deploy-all so the cluster mirrors the repository state.
declare -a overlays=(
  "deployments/cert-manager"
  "deployments/metallb"
  "deployments/gateway-api"
  "deployments/argocd"
  "deployments/portainer"
  "deployments/victoria"
)

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

cd "$(dirname "$0")"

for ((idx=${#overlays[@]}-1; idx>=0; idx--)); do
  overlay="${overlays[idx]}"
  echo "Dropping ${overlay}"
  kustomize build "$overlay" | kubectl delete -f - --ignore-not-found
done
