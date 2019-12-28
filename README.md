# Advanced networking: the Container Network Interface (CNI)

## The CNI plugin

- `my-cni-plugin` is the  plugin executable
- `my-cni-plugin.conf.jsonnet` is the plugin [configuration](https://github.com/containernetworking/cni/blob/master/SPEC.md#network-configuration)

The plugin configuration is a [Jsonnet](https://jsonnet.org/) file since it contains some node-specific parameters.

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

## Testing the CNI plugin

Deploy the four Pods defined in `pods.yaml` to the cluster:

```bash
kubectl apply -f pods.yaml
```

Verify that all Pods have an IP address and that there are two Pods running on each worker node:

```bash
kubectl get pods -o wide
```

> If the IP address of some of the Pods is `<none>`, just wait about a minute and then list the Pods again.

Exec into one of the Pods:

```bash
kubectl exec -it pod-1 sh
```

The following instructions take this configuration as an example:

```
NAME    IP            NODE              NODE_IP 
pod-1   200.200.1.2   my-k8s-worker-1   10.0.0.3
pod-2   200.200.2.4   my-k8s-worker-2   10.0.0.4
pod-3   200.200.2.5   my-k8s-worker-2   10.0.0.4
pod-4   200.200.1.3   my-k8s-worker-1   10.0.0.3
```

Try to ping the following connections:

1. The Pod itself:

    ```bash
    ping 200.200.1.2
    ```

1. The node the Pod is running on:

   ```bash
   ping 10.0.0.3
   ```

1. Another Pod on the same node:

    ```bash
    ping 200.200.1.3
    ```

2. Another Pod on a different node:

    ```bash
    ping 200.200.2.4
    ```

1. A destination outside the cluster:

    ```bash
    ping 198.41.0.4
    ```

## Test notes

### Pod to Pod communication: normal Pods

### Pod to Pod communication: host network Pods

### Pod to node agent communication

### External communication

Test the following types of connections. For each connection, check the IP packet source and destination IP address of both the sender and receiver. They should be the same for both the sender and receiver (which means that there is no NAT taking place).

- Pod to same Pod
- Pod to other Pod on same node
- Pod to other Pod on a different node

- Pod to process on same node
- Process to Pod on same node
- Pod to process on a different node
- Process to Pod on a different node

- Pod to Pod in host namespace on same node
- Pod in host namespace to Pod on same node
- Pod to Pod in host namespace on a different node
- Pod in host namespace to Pod on a different node

- Pod to external destination (echo.nmap.org = 45.33.32.156)
