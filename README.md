# helm-cloudflare-tunnel

A Helm chart that runs a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) connector (`cloudflared`) in Kubernetes. The tunnel token comes from a Secret you already have, the image is pinned, and the pods run locked down.

## Features

- Pinned image: an exact `cloudflare/cloudflared` tag (the chart `appVersion`), an optional digest, never `:latest`. The upstream image is multi-arch (linux/amd64 and linux/arm64).
- Tunnel token from an existing Secret (name and key). The chart never takes the token inline and never creates the Secret.
- Remotely managed ingress by default (the public hostnames live in Cloudflare), with an optional locally managed config (ConfigMap).
- Two replicas by default, a PodDisruptionBudget, topology spread over nodes, and an optional HPA.
- `/ready` liveness and readiness probes, a metrics port, and an optional ServiceMonitor.
- Hardened pods: non-root, read-only root filesystem, all capabilities dropped, `RuntimeDefault` seccomp, no service account token.
- Optional NetworkPolicy: egress to cluster DNS and the Cloudflare edge only (ports 7844 and 443, public addresses), plus the target services you list.
- `values.schema.json` validates the values at install time.

## Quick start

Create the tunnel in Cloudflare (Zero Trust, Networks, Tunnels), add its public hostnames there, and copy the token. Keep the token in a Secret:

```bash
kubectl create namespace cloudflare
kubectl -n cloudflare create secret generic cloudflared-token --from-literal=token="<TUNNEL_TOKEN>"
```

The smallest install ([examples/minimal.yaml](examples/minimal.yaml)):

```yaml
tunnel:
  tokenSecret:
    name: cloudflared-token
```

```bash
helm install cloudflared ./charts/helm-cloudflare-tunnel -n cloudflare -f examples/minimal.yaml
```

The origin in Cloudflare is the in-cluster Service name, for example `http://app.default.svc.cluster.local:80`.

## Configuration

The full list is in [charts/helm-cloudflare-tunnel/values.yaml](charts/helm-cloudflare-tunnel/values.yaml), documented inline. The ones you will reach for:

| Value | Default | Purpose |
| --- | --- | --- |
| `tunnel.tokenSecret.name` | required | Existing Secret that holds the tunnel token |
| `tunnel.tokenSecret.key` | `token` | Key in that Secret |
| `image.tag` | chart `appVersion` | Exact cloudflared version |
| `image.digest` | empty | Pull by digest as well (`sha256:...` of the multi-arch index) |
| `replicaCount` | `2` | Connectors; two means a restart drops nothing |
| `config.enabled` | `false` | Use ingress rules from this chart instead of Cloudflare |
| `config.ingress` | `[]` | Ordered rules: `hostname`, `path`, `service`, `originRequest` |
| `config.noTLSVerify` | `false` | Skip TLS verification of every origin |
| `metrics.serviceMonitor.enabled` | `false` | Create a ServiceMonitor (and the metrics Service) |
| `podDisruptionBudget.enabled` | `true` | Keep a connector up during node drains |
| `autoscaling.enabled` | `false` | HPA instead of `replicaCount` |
| `networkPolicy.enabled` | `false` | Restrict egress; list targets in `networkPolicy.extraEgress` |
| `logging.level` / `logging.format` | `error` / `json` | Production-safe; use `debug` / `default` while developing |

### Pinning by digest

```bash
docker buildx imagetools inspect cloudflare/cloudflared:2026.11.1   # the Digest line of the index
```

```yaml
image:
  digest: sha256:e613aadbc2d9511785d2e67a86b0c8ac18dd63a3f9af0d06faf04cbfdcb35f2d
```

Use the digest of the index, not of one platform, and change it together with the tag.

### Locally managed ingress

By default the tunnel is remotely managed. For a tunnel whose ingress is kept in Git, enable the config:

```yaml
config:
  enabled: true
  ingress:
    - hostname: app.example.org
      service: http://app.default.svc.cluster.local:80
    - hostname: api.example.org
      path: /v1/.*
      service: https://api.default.svc.cluster.local:443
```

The catch-all `http_status:404` rule is added last. A change to the rules rolls the pods. Use this with a tunnel created through the cloudflared CLI: a remotely managed tunnel takes its ingress from Cloudflare.

### NetworkPolicy

Turn it on and list the services the tunnel reaches, as raw egress rules:

```yaml
networkPolicy:
  enabled: true
  extraEgress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: app
      ports:
        - protocol: TCP
          port: 8080
```

It needs a CNI that enforces NetworkPolicy. The edge rule allows port 7844 (TCP and UDP) and 443 to public addresses only.

## Develop

```bash
task check    # helm lint, render every ci/*.yaml values file, kubeconform, yamllint
task template # render with the default CI values
task lint-init
```

CI runs the same checks (`scripts/check-chart.sh`) on every non-draft pull request.

## Releases

Merged pull requests feed a release-drafter draft. The maintainer bumps `version` (and `appVersion` when the cloudflared pin moves) in `Chart.yaml`, then publishes the GitHub Release by hand, which creates the tag. Nothing tags automatically.

## License

MIT, see [LICENSE](LICENSE).
