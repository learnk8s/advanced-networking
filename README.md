# My CNI plugin

## Installation

### 1. Install the plugin executable files

Upload `my-cni-plugin` to `/opt/cni/bin` of each node:

```bash
for node in my-k8s-master my-k8s-worker; do
  gcloud compute scp my-cni-plugin root@"$node":/opt/cni/bin
done
```

### 2. Customise and install the plugin configuration files

Upload `10-my-cni-plugin.conf` to `/etc/cni/net.d` of each node by inserting the node's Pod CIDR range in the file:

```bash
for node in my-k8s-master my-k8s-worker; do
  tmp=$(mktemp -d)/10-my-cni-plugin.conf
  cat 10-my-cni-plugin.conf | sed "s#<PodCIDR>#$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}')#" >"$tmp"
  gcloud compute ssh root@"$node" --command "mkdir -p /etc/cni/net.d"
  gcloud compute scp "$tmp" root@"$node":/etc/cni/net.d
done
```

> For the above commands to work, make sure that the `KUBECONFIG` environment variable is set to your cluster's kubconfig file.
