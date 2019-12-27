#!/bin/bash

set -e

# Parameters
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2
subnet=my-k8s-subnet
plugin_exec=my-cni-plugin
plugin_config=my-cni-plugin.conf.jsonnet
plugin_logs=/var/log/cni/my-cni-plugin.log               # For uninstall only
plugin_setup_done=/var/lib/cni/my-cni-plugin-setup-done  # For uninstall only

install() {

  # Check for jsonnet and jq dependencies
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

  # Check if kubectl is using the right cluster
  if [[ ! "$(kubectl get nodes -o custom-columns=:.metadata.name --no-headers | sort)" == "$(echo -e "$master\n$worker1\n$worker2" | sort)" ]]; then
    echo "Error: kubectl tries to access the wrong cluster."
    echo "       Did you set the KUBECONFIG environment variable?"
    exit 1
  fi

  # Host network CIDR range
  host_net=$(gcloud compute networks subnets describe "$subnet" --format="value(ipCidrRange)")

  # Pod network CIDR range
  pod_net=$(kubectl get pod kube-controller-manager-"$master" -n kube-system -o json |
    jq -r '.spec.containers[0].command[] | select(. | contains("--cluster-cidr"))' |
    sed -rn 's|[^0-9]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]/[0-9][0-9]?)[^0-9]*|\1|p')

  # Upload plugin executable and (customised) configuration to each node
  for node in "$master" "$worker1" "$worker2"; do
    echo "Installing to "$node"..."

    # Pod subnet of current node CIDR range
    pod_node_subnet=$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}')

    # Install plugin executable to /opt/cni/bin
    gcloud compute scp "$plugin_exec" root@"$node":/opt/cni/bin

    # Customise plugin configuration in temporary file
    tmp=$(mktemp -d)/"${plugin_config%.jsonnet}"
    jsonnet -V hostNet="$host_net" -V podNet="$pod_net" -V podNodeSubnet="$pod_node_subnet" "$plugin_config" >"$tmp"

    #tmp=$(mktemp -d)/"${plugin_config%.jsonnet}"
    #jsonnet -V network="$pod_net" -V subnet="$pod_node_subnet" "$plugin_config" >"$tmp"

    # Install plugin configuration to /etc/cni/net.d
    gcloud compute ssh root@"$node" --command "mkdir -p /etc/cni/net.d"
    gcloud compute scp "$tmp" root@"$node":/etc/cni/net.d
  done
}

uninstall() {
  for node in "$master" "$worker1" "$worker2"; do
    echo "Uninstalling from "$node"..."
    gcloud compute ssh root@"$node" --command "rm -rf '/opt/cni/bin/$plugin_exec' '/etc/cni/net.d/\"${plugin_config%.jsonnet}' '$plugin_logs' '$plugin_setup_done'"
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
