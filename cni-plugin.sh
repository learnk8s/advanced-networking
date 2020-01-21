#!/bin/bash
#
# Install or uninstall the CNI plugin on the Kubernetes cluster.
#
# Run this after installing Kubernetes with kubernetes.sh

set -e

# Parameters
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2
subnet=my-k8s-subnet
plugin_executable=my-cni-plugin
netconf_template=my-cni-plugin.conf.jsonnet

install() {

  # Check if kubectl uses the correct kubeconfig file
  if [[ ! "$(kubectl get nodes -o custom-columns=:.metadata.name --no-headers | sort)" == "$(echo -e "$master\n$worker1\n$worker2" | sort)" ]]; then
    echo "Error: trying to connect to the wrong cluster."
    echo "       Did you set the KUBECONFIG environment variable?"
    exit 1
  fi

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

  # Get host network and Pod network CIDR ranges
  host_network=$(gcloud compute networks subnets describe "$subnet" --format="value(ipCidrRange)")
  pod_network=$(kubectl get pod kube-controller-manager-"$master" -n kube-system -o json |
    jq -r '.spec.containers[0].command[] | select(. | contains("--cluster-cidr"))' |
    sed -rn 's|[^0-9]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]/[0-9][0-9]?)[^0-9]*|\1|p')

  # Install the CNI plugin executable and NetConf to all the nodes
  for node in "$master" "$worker1" "$worker2"; do

    # Get Pod subnet CIDR range of current node
    pod_subnet=$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}')

    # Upload CNI plugin executable to /opt/cni/bin
    gcloud compute scp "$plugin_executable" root@"$node":/opt/cni/bin

    # Customise NetConf and upload it to /etc/cni/net.d
    tmp=$(mktemp -d)/"${netconf_template%.jsonnet}"
    jsonnet -V hostNetwork="$host_network" -V podNetwork="$pod_network" -V podSubnet="$pod_subnet" "$netconf_template" >"$tmp"
    gcloud compute ssh root@"$node" --command "mkdir -p /etc/cni/net.d"
    gcloud compute scp "$tmp" root@"$node":/etc/cni/net.d
  done

  cat <<EOF

**************************
😃 CNI plugin installed 😃
**************************

Your nodes should now gradually become ready:

👉 kubectl get nodes

EOF
}

# Uninstall the plugin from all the nodes. Note that this just removes the plugin
# files and does NOT undo any settings made by the plugin.
uninstall() {
  for node in "$master" "$worker1" "$worker2"; do
    echo "Uninstalling from $node..."
    gcloud compute ssh root@"$node" --command "rm -rf '/opt/cni/bin/$plugin_executable' '/etc/cni/net.d/${netconf_template%.jsonnet}'"
  done

  cat <<EOF

****************************
🗑️  CNI plugin uninstalled 🗑️
****************************

Existing Pods keep working, but you can't create any new Pods.

EOF
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
