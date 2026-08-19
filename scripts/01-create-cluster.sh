#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="traefik-cluster"

echo "======================================"
echo "Creating k3d Traefik Cluster"
echo "======================================"

if k3d cluster list 2>/dev/null |
  awk 'NR > 1 {print $1}' |
  grep -qx "$CLUSTER_NAME"; then

  echo "Cluster $CLUSTER_NAME already exists."
else
  k3d cluster create "$CLUSTER_NAME" \
    --api-port 6550 \
    -p "8081:80@loadbalancer"
fi

echo
echo "Waiting for Kubernetes node..."

kubectl wait \
  --for=condition=Ready \
  node \
  --all \
  --timeout=120s

echo
echo "Waiting for Traefik..."

for i in $(seq 1 60); do
  if kubectl get pods -n kube-system \
    -l app.kubernetes.io/name=traefik \
    --no-headers 2>/dev/null |
    grep -q 'Running'; then

    echo "Traefik is running."
    break
  fi

  sleep 2
done

echo
echo "======================================"
echo "Cluster Ready"
echo "======================================"

echo
k3d cluster list

echo
kubectl get nodes -o wide

echo
echo "Traefik:"
kubectl get pods -n kube-system |
  grep -E 'traefik|NAME'

echo
echo "Ingress classes:"
kubectl get ingressclass

echo
echo "Application URL after deployment:"
echo "http://127.0.0.1:8081/whoami"