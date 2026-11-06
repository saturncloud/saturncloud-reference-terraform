#!/usr/bin/env bash
# Installs the calico chart (from scripts/fetch-calico-chart.sh) as release
# calico in kube-system, with the values in $CALICO_VALUES.
#   scripts/install-calico.sh <cluster name> <region> <chart path>
set -euo pipefail

KUBECONFIG=$(mktemp)
VALUES=$(mktemp)
export KUBECONFIG
trap 'rm -f "$KUBECONFIG" "$VALUES"' EXIT
aws eks update-kubeconfig --name "$1" --region "$2" --kubeconfig "$KUBECONFIG" >/dev/null

printf '%s\n' "$CALICO_VALUES" > "$VALUES"
helm upgrade --install calico "$3" -n kube-system -f "$VALUES"
