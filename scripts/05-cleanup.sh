#!/usr/bin/env bash
set -euo pipefail
helm uninstall my-webapp 2>/dev/null || true
k3d cluster delete traefik-cluster
