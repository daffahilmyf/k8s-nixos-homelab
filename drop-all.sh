#!/usr/bin/env bash
set -euo pipefail

# Drop the same overlays as deploy-all so the cluster mirrors the repository state.
declare -a overlays=(
  "deployments/gateway-api"
  "deployments/cert-manager"
  "deployments/metallb"
  "deployments/argocd"
  "deployments/portainer"
  "deployments/victoria"
  
)

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

cd "$(dirname "$0")"

delete_metallb() {
  overlay="deployments/metallb"
  echo "Dropping ${overlay} resources (without CRDs)"
  for resource in metallb.yaml values.yaml l2-advertisement.yaml; do
    kubectl delete -f "${overlay}/${resource}" --ignore-not-found
  done
  echo "Dropping ${overlay} CRDs"
  kubectl delete -f "${overlay}/metallb-crds.yaml" --ignore-not-found
}

for ((idx=${#overlays[@]}-1; idx>=0; idx--)); do
  overlay="${overlays[idx]}"
  if [ "${overlay}" == "deployments/metallb" ]; then
    delete_metallb
    continue
  fi
  echo "Dropping ${overlay}"
  kustomize build "$overlay" | kubectl delete -f - --ignore-not-found
done
