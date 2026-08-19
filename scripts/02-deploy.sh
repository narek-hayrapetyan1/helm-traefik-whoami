#!/usr/bin/env bash
set -euo pipefail
kubectl config use-context k3d-traefik-cluster >/dev/null
helm upgrade --install my-webapp ./my-webapp --namespace default --create-namespace
kubectl rollout status deployment/my-webapp --timeout=180s
echo
kubectl get deployment,service,ingress
kubectl get middleware.traefik.io
kubectl get pods -o wide
