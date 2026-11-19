# helm-cloudflare-tunnel

Runs a Cloudflare Tunnel (cloudflared) connector. The tunnel token is read from an existing Secret.

```bash
kubectl -n cloudflare create secret generic cloudflared-token --from-literal=token="<TUNNEL_TOKEN>"
helm install cloudflared . -n cloudflare --set tunnel.tokenSecret.name=cloudflared-token
```

See the repository README for the full usage, the values table and examples.
