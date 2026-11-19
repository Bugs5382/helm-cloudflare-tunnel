#!/usr/bin/env bash
# Lints the chart, renders it with every values file in charts/*/ci, and validates the output
# against the Kubernetes (and ServiceMonitor) schemas. Used by `task check` and by CI.
set -euo pipefail

CHART_DIR="${CHART_DIR:-charts/helm-cloudflare-tunnel}"
K8S_VERSION="${K8S_VERSION:-1.30.0}"
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

shopt -s nullglob
values_files=("${CHART_DIR}"/ci/*.yaml)
if [ "${#values_files[@]}" -eq 0 ]; then
  echo "no values files in ${CHART_DIR}/ci" >&2
  exit 1
fi

for f in "${values_files[@]}"; do
  echo "==> helm lint ${f}"
  helm lint --strict "${CHART_DIR}" -f "${f}"
  echo "==> helm template + kubeconform ${f}"
  helm template check "${CHART_DIR}" -f "${f}" \
    | kubeconform -strict -summary -kubernetes-version "${K8S_VERSION}" \
        -schema-location default -schema-location "${CRD_SCHEMAS}"
done

# The Secret name is required: a render without it must fail with the schema message.
echo "==> a render without tunnel.tokenSecret.name must fail"
if helm template check "${CHART_DIR}" >/dev/null 2>&1; then
  echo "render without a token Secret name unexpectedly succeeded" >&2
  exit 1
fi
echo "==> image.tag=latest must fail"
if helm template check "${CHART_DIR}" -f "${values_files[0]}" --set image.tag=latest >/dev/null 2>&1; then
  echo "render with image.tag=latest unexpectedly succeeded" >&2
  exit 1
fi
# Dry run of the release packaging: the chart must package, under the name the publish job pushes.
echo "==> helm package (dry run)"
pkg_dir="$(mktemp -d)"
trap 'rm -rf "$pkg_dir"' EXIT
helm package "${CHART_DIR}" -d "${pkg_dir}" >/dev/null
chart_version="$(sed -n 's/^version: *//p' "${CHART_DIR}/Chart.yaml" | tr -d '"' | head -n1)"
test -f "${pkg_dir}/helm-cloudflare-tunnel-${chart_version}.tgz" \
  || { echo "packaged chart is not helm-cloudflare-tunnel-${chart_version}.tgz" >&2; exit 1; }
echo "chart checks passed"
