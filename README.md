# Dynamic Helm Templating & Traefik Ingress Routing

This project demonstrates parameterized Kubernetes deployment with Helm and Layer 7 path routing through the Traefik ingress controller bundled with K3s/k3d.

## Architecture

```text
curl/browser
    |
    | http://127.0.0.1:8081/whoami
    v
k3d load balancer :80
    |
    v
Traefik Ingress Controller
    |
    | matches /whoami
    v
StripPrefix Middleware
    | /whoami -> /
    v
ClusterIP Service :80
    |
    +----> traefik/whoami pod
    |
    +----> traefik/whoami pod
```

## Requirements

Install Docker, k3d, kubectl, Helm, and curl. On macOS with Homebrew:

```bash
brew install k3d kubectl helm
```

Docker Desktop must be running.

## 1. Create the k3d cluster

```bash
./scripts/01-create-cluster.sh
```

Equivalent command:

```bash
k3d cluster create traefik-cluster \
  --api-port 6550 \
  -p '8081:80@loadbalancer'
```

Port 8081 on the workstation is mapped to port 80 on the k3d load balancer, which forwards HTTP traffic to Traefik.

Verify:

```bash
k3d cluster list
kubectl get nodes -o wide
kubectl -n kube-system get deployment,pods -l app.kubernetes.io/name=traefik
```

## 2. Helm chart

The finished chart is under `my-webapp/`. It is the customized equivalent of starting with:

```bash
helm create my-webapp
```

Important values:

```yaml
replicaCount: 2

image:
  repository: traefik/whoami
  tag: latest

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    traefik.ingress.kubernetes.io/router.middlewares: default-my-webapp-strip-whoami@kubernetescrd
  hosts:
    - host: ""
      paths:
        - path: /whoami
          pathType: Prefix
```

## 3. StripPrefix middleware

`templates/middleware.yaml` renders a Traefik CRD:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: my-webapp-strip-whoami
spec:
  stripPrefix:
    prefixes:
      - /whoami
```

The Ingress annotation references it using Traefik's Kubernetes CRD provider naming format:

```text
default-my-webapp-strip-whoami@kubernetescrd
```

Requests therefore flow as:

```text
Client request:  GET /whoami
Traefik route:   matches /whoami
Middleware:      strips /whoami
Backend request: GET /
```

## 4. Validate the Helm chart before deployment

```bash
./scripts/04-render.sh
```

Or:

```bash
helm lint ./my-webapp
helm template my-webapp ./my-webapp
```

## 5. Deploy

```bash
./scripts/02-deploy.sh
```

Equivalent Helm command:

```bash
helm upgrade --install my-webapp ./my-webapp
```

Verify resources:

```bash
helm list
kubectl get deployment,service,ingress
kubectl get middleware.traefik.io
kubectl get pods -o wide
```

Expected Deployment status:

```text
my-webapp   2/2
```

## 6. Test Traefik routing

```bash
curl -i http://127.0.0.1:8081/whoami
```

Expected result is HTTP 200 from `traefik/whoami`. In the whoami request details, the backend path should be `/`, demonstrating that the middleware stripped `/whoami` before forwarding the request.

Useful comparison:

```bash
curl -i http://127.0.0.1:8081/whoami
curl -i http://127.0.0.1:8081/not-configured
```

The configured `/whoami` route should reach the application, while an unrelated path should not match this Ingress rule.

## 7. Automated verification

```bash
./scripts/03-verify.sh
```

The script checks:

- k3d cluster exists
- Traefik is installed
- Helm release is deployed
- two replicas are configured and ready
- `traefik/whoami:latest` is used
- Service is ClusterIP on port 80
- Ingress class is `traefik`
- Ingress path is `/whoami`
- StripPrefix middleware exists
- Ingress references the middleware
- application responds through host port 8081
- backend sees `/` after prefix stripping

## 8. Helm dynamic templating demonstration

Show that deployment settings can change without editing static Kubernetes manifests:

```bash
helm upgrade my-webapp ./my-webapp --set replicaCount=3
kubectl rollout status deployment/my-webapp
kubectl get deployment my-webapp
```

Return to the required value:

```bash
helm upgrade my-webapp ./my-webapp --set replicaCount=2
```

This demonstrates the main benefit of Helm: environment-specific values are supplied independently of the Kubernetes templates.

## 9. Cleanup

```bash
./scripts/05-cleanup.sh
```
