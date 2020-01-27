# Advanced networking — Pod networking and CNI plugins

GitHub repository of the course [_Advanced networking — Pod networking and CNI plugins_](https://academy-dev.learnk8s.io/advanced-networking/intro) of the [Lernk8s Academy](https://learnk8s.io/academy).

The course contains a lab for building your own CNI plugin from scratch.

This repository contains:

- The CNI plugin ([`my-cni-plugin`](https://github.com/learnk8s/advanced-networking/blob/master/my-cni-plugin))
- Scripts for creating the Kubernetes cluster and installing the CNI plugin

## Scripts

There are four shell scripts:

1. `infrastructure.sh`: create GCP infrastructure
1. `kubernetes.sh`: install Kubernetes
1. `cni-plugin.sh`: install CNI plugin
1. `inter-node-routes.sh`: create GCP inter-node communication routes

The scripts have the following interdependencies:

```
                        +------- kubernetes.sh <------------- cni-plugin.sh
infrastructure.sh <-----|
                        +------- inter-node-routes.sh
```

That means, for example, `kubernetes.sh` must be run after `infrastructure.sh`, etc.

Each script has `up` and `down` commands that do and undo the actions of the script.

## Using the scripts

### `infrastructure.sh`

Create the GCP resources for the Kubernetes cluster:

```bash
./infrastructure.sh up
```

Delete the GCP resources:

```bash
./infrastructure.sh down
```

### `kubernetes.sh`

Install Kubernetes on the GCP infrastructure:

```bash
./kubernetes.sh up
```

Uninstall Kubernetes:

```bash
./kubernetes.sh down
```

### `cni-plugin.sh`

Install the CNI plugin on the Kubernetes cluster:

```bash
./cni-plugin.sh up
```

Uninstall the CNI plugin:

```bash
./cni-plugin.sh down
```

**Caution:** the `down` command only removes the CNI plugin files but does not undo any settings made by the CNI plugin.

### `inter-node-routes.sh`

Create inter-node communication routes in the GCP subnet:

```bash
./inter-node-routes.sh up
```

Remove the inter-node communication routes:

```bash
./inter-node-routes.sh down
```

**Note:** if you install the CNI plugin without creating the inter-node communication routes, then Pods on different nodes can't communicate with each other (Pods on the same node, however, can communicate). Also, the cluster DNS doesn't work if there are no inter-node communication routes. As soon as you install the routes, inter-node communication between all types of entities should work.

## Testing the CNI plugin

Deploy the four Pods defined in `pods.yaml` to the cluster:

```bash
kubectl apply -f pods.yaml
```

Verify that all Pods got an IP address and that two Pods are running on each worker node:

```bash
kubectl get pods -o wide
```

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

Verify the following connectivities with `ping`:

1. To a Pod on the same node:

    ```bash
    ping 200.200.1.3
    ```

1. To a Pod on a different node:

   ```bash
   ping 200.200.2.4
   ```

1. To the default network namespace of the same node:

   ```bash
   ping 10.0.0.3
   ```

1. To the default network namespace of a different node:

   ```bash
   ping 10.0.0.4
   ```

1. To a destination outside the cluster:

    ```bash
    ping learnk8s.io
    ```

You should also test the connectivity to the Pods from a process in the default network namespace of a node.

To do so, log into one of the nodes:

```bash
gcloud compute ssh root@my-k8s-worker-1
```

Then verify the following connectivities with `ping`:

1. To a Pod on the same node:

    ```bash
    ping 200.200.1.2
    ```

1. To a Pod on a different node:

    ```bash
    ping 200.200.2.4
    ```
