#!/bin/bash
#
# Create or delete the inter-node Pod-to-Pod communication routes that complete
# the functionality of the CNI plugin.
#
# Run this anytime after installing Kubernetes with kubernetes.sh

master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2
vpc=my-k8s-vpc

up() {

  # Check if kubectl uses the correct kubeconfig file
  if [[ ! "$(kubectl get nodes -o custom-columns=:.metadata.name --no-headers | sort)" == "$(echo -e "$master\n$worker1\n$worker2" | sort)" ]]; then
    echo "Error: trying to connect to the wrong cluster."
    echo "       Did you set the KUBECONFIG environment variable?"
    exit 1
  fi

  # Create routes
  for node in "$master" "$worker1" "$worker2"; do
    node_ip=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    pod_subnet=$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}')
    gcloud compute routes create "$node" --network="$vpc" --destination-range="$pod_subnet" --next-hop-address="$node_ip"
  done

  cat <<EOF

*********************************************
😃 Inter-node communication routes created 😃
*********************************************

Your Pods should now be able to communicate with Pods on different nodes.

EOF
}

down() {
  gcloud -q compute routes delete "$master" "$worker1" "$worker2"
  cat <<EOF

*********************************************
🗑️  Inter-node communication routes deleted 🗑️
*********************************************

Your Pods can't communicate with Pods on different nodes anymore.
However, Pods can still communicate with Pods on the same node.

EOF
}

usage() {
  echo "USAGE:"
  echo "  $(basename $0) up|down"
}

case "$1" in
  up) up;;
  down) down;;
  *) usage && exit 1 ;;
esac
