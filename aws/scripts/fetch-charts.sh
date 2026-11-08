#!/usr/bin/env bash
# Copies the calico and coredns charts out of the saturn-helm-operator image,
# so Terraform installs exactly the charts the operator will later manage.
#   scripts/fetch-charts.sh <operator image tag> [dest]
# The tag is the chart's image.tag, e.g. 2026.02.01-147 for chart 2026.2.1-147.
set -euo pipefail

TAG=$1
DEST=${2:-"$(dirname "$0")/../.charts"}
IMAGE="saturncloud/saturn-helm-operator:$TAG"
NAME="saturn-charts-$$"

docker pull -q "$IMAGE" >/dev/null
docker create --name "$NAME" "$IMAGE" >/dev/null
trap 'docker rm "$NAME" >/dev/null' EXIT
mkdir -p "$DEST"
for chart in calico coredns; do
  rm -rf "${DEST:?}/$chart"
  docker cp "$NAME:/opt/helm/charts/$chart" "$DEST/$chart"
  echo "$chart chart $(grep '^appVersion' "$DEST/$chart/Chart.yaml") copied to $DEST/$chart"
done
