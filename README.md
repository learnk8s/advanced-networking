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

> This script must be executed from the same directory as the plugin executable and config files.

You can uninstall the plugin with:

```bash
./plugin.sh uninstall
```

However, note that this just deletes the files from the nodes, it doesn't revert the settings made by the plugin if it has already been run (e.g. creation of the bridge).

## Testing the CNI plugin

Deploy the four Pods defined in `pods.yaml` to the cluster:

```bash
kubectl apply -f pods.yaml
```

Verify that all Pods got an IP address and that there are two Pods running on each worker node:

```bash
kubectl get pods -o wide
```

> If the IP address of some of the Pods is `<none>`, just wait about a minute and then list the Pods again.

Exec into one of the Pods:

```bash
kubectl exec -it pod-1 bash
```

The instructions below will use the following configuration as an example:

```
NAME    IP            NODE              NODE_IP 
pod-1   200.200.1.2   my-k8s-worker-1   10.0.0.3
pod-2   200.200.2.4   my-k8s-worker-2   10.0.0.4
pod-3   200.200.2.5   my-k8s-worker-2   10.0.0.4
pod-4   200.200.1.3   my-k8s-worker-1   10.0.0.3
```

Probe the following connections with the `my-nping`  script that is available in the container:

1. To a Pod on the same node:

    ```bash
    my-nping 200.200.1.3
    ```

1. To a Pod on a different node:

   ```bash
   my-nping 200.200.2.4
   ```

1. To a destination outside the cluster:

    ```bash
    my-nping echo.nmap.org
    ```

You also have to test the connectivity form a process running directly on the node (like the kubelet) to the Pods. To do so, log into one of the nodes:

```bash
gcloud compute ssh root@my-k8s-worker-1
```

And download the `my-nping` wrapper script:

```bash
curl https://raw.githubusercontent.com/learnk8s/docker-advanced-networking/master/my-nping >my-nping
chmod +x my-nping
```

Now, test the following connections:

1. To a Pod on the same node:

    ```bash
    ./my-nping 200.200.1.2
    ```

1. To a Pod on a different node:

    ```bash
    ./my-nping 200.200.2.4
    ```
