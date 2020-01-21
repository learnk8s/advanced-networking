#!/bin/bash
#
# Create or delete the GCP infrastructure for the Kubernetes cluster.
#
# Run this before any other scripts.

host_network=10.0.0.0/16
pod_network=200.200.0.0/16
vpc=my-k8s-vpc
subnet=my-k8s-subnet
firewall_internal=my-k8s-internal
firewall_ingress=my-k8s-ingress
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2

create() {
  set -e

  gcloud compute networks create "$vpc" --subnet-mode custom
  gcloud compute networks subnets create "$subnet" --network "$vpc" --range "$host_network"
  gcloud compute instances create "$master" \
      --machine-type n1-standard-2 \
      --subnet "$subnet" \
      --image-family ubuntu-1804-lts \
      --image-project ubuntu-os-cloud \
      --can-ip-forward
  gcloud compute instances create "$worker1" "$worker2" \
      --machine-type n1-standard-1 \
      --subnet "$subnet" \
      --image-family ubuntu-1804-lts \
      --image-project ubuntu-os-cloud \
      --can-ip-forward
  gcloud compute firewall-rules create "$firewall_ingress" --network "$vpc" --allow tcp:22,tcp:6443
  gcloud compute firewall-rules create "$firewall_internal" --network "$vpc" --allow tcp,udp,icmp --source-ranges "$host_network","$pod_network"

  # Wait for SSH access to succeed (may take up to 30 sec.)
  while ! gcloud compute ssh "$master" --command "echo test" &>/dev/null; do
    echo "Waiting for SSH access..."
    sleep 10
  done

  cat <<EOF

********************************
😃 GCP infrastructure created 😃
********************************

You can access your VM instances with:

👉 gcloud compute ssh $master
👉 gcloud compute ssh $worker1
👉 gcloud compute ssh $worker2

EOF
}

delete() {
  gcloud -q compute instances delete "$master" "$worker1" "$worker2"
  gcloud -q compute firewall-rules delete "$firewall_ingress" "$firewall_internal"
  gcloud -q compute networks subnets delete "$subnet"
  gcloud -q compute networks delete "$vpc"

  cat <<EOF

********************************
🗑️  GCP infrastructure deleted 🗑️
********************************

EOF
}

usage() {
  echo "USAGE:"
  echo "  $(basename $0) create|delete"
}

case "$1" in
  up) up ;;
  down) down ;;
  *) usage && exit 1 ;;
esac
