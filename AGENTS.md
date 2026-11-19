# AGENTS.md - helm-cloudflare-tunnel

Guide for AI agents working in this repository. Pair with `CLAUDE.md` (the working agreement and
hook-enforced rules). Keep this file current when the build, layout, or public API changes.

## What this is

A standalone Helm chart (`charts/helm-cloudflare-tunnel`) that runs a Cloudflare Tunnel (cloudflared)
connector. It is consumed by other charts and releases as a plain chart; there is no Go code.

Things to understand before changing it:

- The tunnel token is only ever read from an existing Secret (`tunnel.tokenSecret`). Never add an
  inline token value or a Secret template.
- The image is an exact tag (default: the chart `appVersion`) with an optional digest. `latest` is
  rejected by the template and the schema. When the cloudflared pin moves, change `appVersion` in
  `Chart.yaml` and update the digest example in `README.md`.
- Ingress is remotely managed in Cloudflare by default; `config.*` is the optional locally managed
  mode. `config.noTLSVerify` stays off by default.

## Layout

- `charts/helm-cloudflare-tunnel/` - the chart: `Chart.yaml`, `values.yaml`, `values.schema.json`,
  `templates/`, and `ci/*.yaml` (values files that CI renders; add one per new feature switch).
- `examples/` - example values for users.
- `scripts/check-chart.sh` - lint, render and kubeconform; used by `task check` and CI.
- `.github/workflows/job-chart-ci.yaml` - the chart check on non-draft PRs.
- `.github/workflows/job-chart-publish.yaml` - on a published release only: checks the tag against
  `Chart.yaml` `version`, pushes the chart to `ghcr.io/bugs5382/charts`, attaches the package.

## Build, test, lint

- Check everything: `task check` (needs helm, kubeconform, yamllint; `task lint-init` installs them)
- Render: `task template`
- Keep `values.yaml`, `values.schema.json` and the README values table in step.

## Logging

Follow the logging rules in `CLAUDE.md`. In short:

- Log generously: entry and exit of significant operations, decisions and branches, retries, state
  changes, external calls (target, duration, outcome), and every error with its context.
- Levels: `trace` for step-by-step detail, `debug` for flow, `info` for lifecycle, `warn` and
  `error` for problems. The environment filters the volume, so err on the side of too much.
- Environments: local dev `trace` with `LOG_FORMAT=console` (never JSON), dev cluster `debug`,
  qa/staging `info`, production `error`. Every cluster environment logs JSON. Set levels through
  `LOG_LEVEL` and `LOG_FORMAT`, never in code; local settings live in the run target or
  `.env.example`.
- Never log secrets, tokens, or personal data, not even at `trace`. Log an opaque or keyed ID.

## Conventions and gotchas

- See `CLAUDE.md` for the branch/commit/PR rules; they are enforced by the git hooks in
  `.claude/hooks` (run `bash .claude/hooks/install.sh` once per clone).
- Open every PR as a draft. CI skips drafts, so run the full checks locally, push once they pass,
  and mark the PR ready when the work is finished; see CLAUDE.md "CI and Actions minutes".
- The chart ships no Go code; the Go scaffold files were removed. Do not reintroduce `go.mod` or golic.
- Chart `version` and `appVersion` are bumped by hand in `Chart.yaml` before the maintainer publishes a
  release; nothing tags automatically.
