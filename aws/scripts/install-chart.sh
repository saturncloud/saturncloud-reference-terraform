#!/usr/bin/env bash
# Installs a chart from scripts/fetch-charts.sh as a release in kube-system,
# with the values in $CHART_VALUES.
#   scripts/install-chart.sh <cluster name> <region> <release> <chart path>
set -euo pipefail

KUBECONFIG=$(mktemp)
VALUES=$(mktemp)
export KUBECONFIG
trap 'rm -f "$KUBECONFIG" "$VALUES"' EXIT
aws eks update-kubeconfig --name "$1" --region "$2" --kubeconfig "$KUBECONFIG" >/dev/null

printf '%s\n' "$CHART_VALUES" > "$VALUES"
helm upgrade --install "$3" "$4" -n kube-system -f "$VALUES"
