# Advanced Networking: the Container Network Interface (CNI)

## The CNI plugin

- `my-cni-plugin` is the  plugin executable
- `my-cni-plugin.conf.jsonnet` is the plugin [configuration](https://github.com/containernetworking/cni/blob/master/SPEC.md#network-configuration)

The plugin configuration is a [Jsonnet](https://jsonnet.org/) file since the Pod CIDR field must be customised for each Kubernetes node.

## Creating the cluster

To create the Kubernetes cluster (without a CNI plugin), use the `cluster.sh` script:

```bash
./cluster.sh up
```

To tear down the cluster, use:

```bash
./cluster.sh down
```

## Installing the CNI plugin

To install the CNI plugin on each Kubernetes node, use the `plugin.sh` script:

```bash
./plugin.sh install
```

To uninstall the plugin, use:

```bash
./plugin.sh uninstall
```

> This script must be executed from the same directory as the plugin executable and config files.
