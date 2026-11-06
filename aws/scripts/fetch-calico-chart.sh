#!/usr/bin/env bash
# Copies the calico chart out of the saturn-helm-operator image, so Terraform
# installs exactly the chart the operator will later manage.
#   scripts/fetch-calico-chart.sh <operator image tag> [dest]
# The tag is the chart's image.tag, e.g. 2026.02.01-147 for chart 2026.2.1-147.
set -euo pipefail

TAG=$1
DEST=${2:-"$(dirname "$0")/../.charts"}
IMAGE="saturncloud/saturn-helm-operator:$TAG"
NAME="calico-chart-$$"

docker pull -q "$IMAGE" >/dev/null
docker create --name "$NAME" "$IMAGE" >/dev/null
trap 'docker rm "$NAME" >/dev/null' EXIT
rm -rf "$DEST/calico"
mkdir -p "$DEST"
docker cp "$NAME:/opt/helm/charts/calico" "$DEST/calico"
echo "calico chart $(grep '^appVersion' "$DEST/calico/Chart.yaml") copied to $DEST/calico"
