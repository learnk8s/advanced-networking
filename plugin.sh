#!/bin/bash

set -e

# Parameters
plugin_exec=my-cni-plugin
plugin_config=my-cni-plugin.conf.jsonnet
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2

install() {
  # Depends on jsonnet to fill in Pod CIDR range in plugin configuration
  if ! which -s jsonnet; then
    echo "Please install jsonnet:"
    [[ "$OSTYPE" =~ darwin ]] && echo "  brew install jsonnet"
    [[ "$OSTYPE" =~ linux ]] && echo "  sudo snap install jsonnet"
  fi
  for node in "$master" "$worker1" "$worker2"; do
    echo "Installing to "$node"..."
    # Install plugin executable to /opt/cni/bin
    gcloud compute scp "$plugin_exec" root@"$node":/opt/cni/bin
    # Install plugin configuration /etc/cni/net.d
    tmp=$(mktemp -d)/"${plugin_config%.jsonnet}"
    jsonnet -V podCIDR=$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}') "$plugin_config" >"$tmp"
    gcloud compute ssh root@"$node" --command "mkdir -p /etc/cni/net.d"
    gcloud compute scp "$tmp" root@"$node":/etc/cni/net.d
  done
}

uninstall() {
  for node in "$master" "$worker1" "$worker2"; do
    echo "Uninstalling from "$node"..."
    gcloud compute ssh root@"$node" --command "rm -f /opt/cni/bin/"$plugin_exec" /etc/cni/net.d/${plugin_config%.jsonnet}"
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
