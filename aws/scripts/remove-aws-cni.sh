#!/usr/bin/env bash
# The objects saturn-aws deletes before the first node joins
# (charts.py AWS_CNI_RESOURCES, os_exec.py delete). Unlike saturn-aws this
# fails if a delete fails, other than "not found".
#   scripts/remove-aws-cni.sh <cluster name> <region>
set -euo pipefail

KUBECONFIG=$(mktemp)
export KUBECONFIG
trap 'rm -f "$KUBECONFIG"' EXIT
aws eks update-kubeconfig --name "$1" --region "$2" --kubeconfig "$KUBECONFIG" >/dev/null

nodes=$(kubectl get nodes -o name | wc -l)
if [ "$nodes" -ne 0 ]; then
  echo "refusing to remove the AWS CNI: the cluster has $nodes node(s); it must have none" >&2
  exit 1
fi

kubectl delete daemonset aws-node -n kube-system --wait=true --ignore-not-found
kubectl delete serviceaccount aws-node -n kube-system --wait=true --ignore-not-found
kubectl delete clusterrole aws-node --wait=true --ignore-not-found
kubectl delete clusterrolebinding aws-node --wait=true --ignore-not-found
kubectl delete customresourcedefinition eniconfigs.crd.k8s.amazonaws.com --wait=true --ignore-not-found
