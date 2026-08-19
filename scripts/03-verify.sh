#!/usr/bin/env bash
set -euo pipefail
PASS=0
FAIL=0
pass(){ printf '[PASS] %s\n' "$1"; PASS=$((PASS+1)); }
fail(){ printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
check_eq(){ local d=$1 got=$2 want=$3; if [ "$got" = "$want" ]; then pass "$d"; else fail "$d (got: $got, expected: $want)"; fi; }

echo 'Helm + Traefik Verification'
echo '==========================='

if k3d cluster list | awk 'NR>1 {print $1}' | grep -qx traefik-cluster; then pass 'k3d cluster exists'; else fail 'k3d cluster exists'; fi
if kubectl -n kube-system get deployment traefik >/dev/null 2>&1; then pass 'Traefik deployment exists'; else fail 'Traefik deployment exists'; fi
check_eq 'Helm release is deployed' "$(helm status my-webapp -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["status"])')" deployed
check_eq 'Replica count is 2' "$(kubectl get deploy my-webapp -o jsonpath='{.spec.replicas}')" 2
check_eq 'Two replicas are ready' "$(kubectl get deploy my-webapp -o jsonpath='{.status.readyReplicas}')" 2
check_eq 'Image is traefik/whoami:latest' "$(kubectl get deploy my-webapp -o jsonpath='{.spec.template.spec.containers[0].image}')" traefik/whoami:latest
check_eq 'Service type is ClusterIP' "$(kubectl get svc my-webapp -o jsonpath='{.spec.type}')" ClusterIP
check_eq 'Service port is 80' "$(kubectl get svc my-webapp -o jsonpath='{.spec.ports[0].port}')" 80
check_eq 'Ingress class is traefik' "$(kubectl get ingress my-webapp -o jsonpath='{.spec.ingressClassName}')" traefik
check_eq 'Ingress path is /whoami' "$(kubectl get ingress my-webapp -o jsonpath='{.spec.rules[0].http.paths[0].path}')" /whoami
check_eq 'Middleware strips /whoami' "$(kubectl get middleware.traefik.io my-webapp-strip-whoami -o jsonpath='{.spec.stripPrefix.prefixes[0]}')" /whoami
check_eq 'Ingress references middleware' "$(kubectl get ingress my-webapp -o jsonpath='{.metadata.annotations.traefik\.ingress\.kubernetes\.io/router\.middlewares}')" default-my-webapp-strip-whoami@kubernetescrd

BODY=$(curl --fail --silent --show-error http://127.0.0.1:8081/whoami 2>/dev/null || true)
if [ -n "$BODY" ]; then pass 'Application responds through Traefik at /whoami'; else fail 'Application responds through Traefik at /whoami'; fi
if printf '%s\n' "$BODY" | grep -Eq 'GET / HTTP|GET / '; then pass 'StripPrefix changed backend request path to /'; else fail 'StripPrefix changed backend request path to /'; fi

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo 'All verification checks passed.'
