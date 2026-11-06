#!/usr/bin/env bash
# saturn-aws config.py CoreDNS._install / os_exec.py adopt: mark the CoreDNS
# objects EKS created as belonging to Helm release coredns in kube-system,
# so the operator's CoreDNS release can take them over.
#   scripts/adopt-coredns.sh <cluster name> <region>
set -euo pipefail

KUBECONFIG=$(mktemp)
export KUBECONFIG
trap 'rm -f "$KUBECONFIG"' EXIT
aws eks update-kubeconfig --name "$1" --region "$2" --kubeconfig "$KUBECONFIG" >/dev/null

for obj in deployment/coredns configmap/coredns service/kube-dns clusterrole/system:coredns; do
  if kubectl get -n kube-system "$obj" >/dev/null 2>&1; then
    kubectl label -n kube-system "$obj" app.kubernetes.io/managed-by=Helm --overwrite
    kubectl annotate -n kube-system "$obj" meta.helm.sh/release-name=coredns meta.helm.sh/release-namespace=kube-system --overwrite
  fi
done
