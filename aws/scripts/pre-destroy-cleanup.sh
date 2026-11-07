#!/usr/bin/env bash
# Called by `terraform destroy` before the Saturn operator is uninstalled.
# Removes the in-cluster objects that own AWS resources Terraform does not
# track, then waits for AWS to delete them:
#   - Services of type LoadBalancer (Traefik, ssh-proxy) -> ELBs and their security groups
#   - PersistentVolumeClaims (Postgres, Elasticsearch, Prometheus, workspaces) -> EBS volumes
# It also releases the operator's finalizers on the components it leaves in
# place (Calico, CoreDNS), so uninstalling the operator cannot hang.
set -euo pipefail

CLUSTER=$1
REGION=$2
KUBECONFIG=$(mktemp)
export KUBECONFIG
trap 'rm -f "$KUBECONFIG"' EXIT

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --kubeconfig "$KUBECONFIG" >/dev/null

# Kinds whose releases own load balancers, volumes or workloads. Calico and
# CoreDNS stay so the cluster keeps networking and DNS until the end.
REMOVE_KINDS="atlas authserver traefik sshproxy logging monitoring pandora phoebe networkfilesystem clusterautoscaler clustersetup certmanager httpreqwebhook spegel jobset"
KEEP_KINDS="calico coredns"

for kind in $REMOVE_KINDS; do
  kubectl get "$kind.charts.saturncloud.io" -A -o json 2>/dev/null |
    jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' |
    while read -r ns name; do
      echo "deleting $kind $ns/$name"
      kubectl delete "$kind.charts.saturncloud.io" "$name" -n "$ns" --wait=false || true
    done
done

# Workspaces, jobs and deployments Atlas started live outside the releases.
kubectl delete svc -A --field-selector spec.type=LoadBalancer --wait=false 2>/dev/null || true

echo "waiting for the operator to uninstall the component releases"
for _ in $(seq 1 60); do
  left=0
  for kind in $REMOVE_KINDS; do
    n=$(kubectl get "$kind.charts.saturncloud.io" -A -o name 2>/dev/null | wc -l)
    left=$((left + n))
  done
  [ "$left" -eq 0 ] && break
  sleep 10
done

kubectl delete svc -A --field-selector spec.type=LoadBalancer --wait=true --timeout=10m 2>/dev/null || true
kubectl delete pvc -A --all --wait=true --timeout=10m 2>/dev/null || true

echo "waiting for EBS-backed PersistentVolumes to be released"
for _ in $(seq 1 60); do
  [ "$(kubectl get pv -o name 2>/dev/null | wc -l)" -eq 0 ] && break
  sleep 10
done

for kind in $KEEP_KINDS; do
  kubectl get "$kind.charts.saturncloud.io" -A -o json 2>/dev/null |
    jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' |
    while read -r ns name; do
      kubectl patch "$kind.charts.saturncloud.io" "$name" -n "$ns" --type=merge -p '{"metadata":{"finalizers":[]}}' || true
    done
done

remaining_lbs=$(kubectl get svc -A --field-selector spec.type=LoadBalancer -o name 2>/dev/null | wc -l)
remaining_pvs=$(kubectl get pv -o name 2>/dev/null | wc -l)
echo "cleanup done: $remaining_lbs LoadBalancer services and $remaining_pvs PersistentVolumes left"

# Stop the destroy rather than leak AWS resources Terraform does not track.
# This resource stays in the state, so the next `terraform destroy` runs the
# cleanup again.
if [ "$remaining_lbs" -ne 0 ] || [ "$remaining_pvs" -ne 0 ]; then
  echo "refusing to continue: these would be left behind in AWS" >&2
  kubectl get svc -A --field-selector spec.type=LoadBalancer >&2 || true
  kubectl get pv >&2 || true
  kubectl get volumeattachments -o custom-columns=PV:.spec.source.persistentVolumeName,ERROR:.status.detachError.message >&2 || true
  exit 1
fi
