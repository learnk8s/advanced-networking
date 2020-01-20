#!/bin/bash

set -e

# Parameters
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2
subnet=my-k8s-subnet
plugin_executable=my-cni-plugin
netconf=my-cni-plugin.conf.jsonnet
plugin_logs=/var/log/cni/my-cni-plugin.log               # For uninstall only
plugin_setup_done=/var/lib/cni/my-cni-plugin-setup-done  # For uninstall only

# Install CNI plugin to all nodes of the cluster
install() {

  # Check if dependencies are available
  if ! which -s jsonnet; then
    echo "Please install jsonnet:"
    [[ "$OSTYPE" =~ darwin ]] && echo "  brew install jsonnet"
    [[ "$OSTYPE" =~ linux ]] && echo "  sudo snap install jsonnet"
    exit 1
  fi
  if ! which -s jq; then
    echo "Please install jq:"
    [[ "$OSTYPE" =~ darwin ]] && echo "  brew install jq"
    [[ "$OSTYPE" =~ linux ]] && echo "  sudo apt-get install jq"
    exit 1
  fi

  # Check if the correct kubeconfig file is being used
  if [[ ! "$(kubectl get nodes -o custom-columns=:.metadata.name --no-headers | sort)" == "$(echo -e "$master\n$worker1\n$worker2" | sort)" ]]; then
    echo "Error: connecting to the wrong cluster."
    echo "       Did you set the KUBECONFIG environment variable?"
    exit 1
  fi

  # Get host network and Pod network CIDR ranges
  host_network=$(gcloud compute networks subnets describe "$subnet" --format="value(ipCidrRange)")
  pod_network=$(kubectl get pod kube-controller-manager-"$master" -n kube-system -o json |
    jq -r '.spec.containers[0].command[] | select(. | contains("--cluster-cidr"))' |
    sed -rn 's|[^0-9]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]/[0-9][0-9]?)[^0-9]*|\1|p')

  # Install the CNI plugin executable and NetConf to all the nodes
  for node in "$master" "$worker1" "$worker2"; do
    echo "Installing to "$node"..."

    # Get Pod subnet CIDR range of current node
    pod_subnet=$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}')

    # Upload CNI plugin executable to /opt/cni/bin
    gcloud compute scp "$plugin_executable" root@"$node":/opt/cni/bin

    # Customise NetConf and upload it to /etc/cni/net.d
    tmp=$(mktemp -d)/"${netconf%.jsonnet}"
    jsonnet -V hostNetwork="$host_network" -V podNetwork="$pod_network" -V podSubnet="$pod_subnet" "$netconf" >"$tmp"
    gcloud compute ssh root@"$node" --command "mkdir -p /etc/cni/net.d"
    gcloud compute scp "$tmp" root@"$node":/etc/cni/net.d
  done
}

# Uninstall the plugin from all the nodes. Note that this just removes the plugin
# files and does NOT undo any settings made by the plugin.
uninstall() {
  for node in "$master" "$worker1" "$worker2"; do
    echo "Uninstalling from "$node"..."
    gcloud compute ssh root@"$node" --command "rm -rf '/opt/cni/bin/$plugin_executable' '/etc/cni/net.d/\"${netconf%.jsonnet}' '$plugin_logs' '$plugin_setup_done'"
  done
}

usage() {
  echo "USAGE:"
  echo "  $(basename $0) install|uninstall"
}

case "$1" in
  install) install ;;
  uninstall) uninstall ;;
  *) usage && exit 1 ;;
esac
