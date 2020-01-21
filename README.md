# Advanced networking lab — Building your own CNI plugin

This repository contains the source code of the CNI plugin ([`my-cni-plugin`](https://github.com/learnk8s/advanced-networking/blob/master/my-cni-plugin)), as well as scripts for creating the Kubernetes cluster and installing the CNI plugin.

## Usage of the scripts

There are four helper scripts with the following interdependencies:

```
                        +------- kubernetes.sh <------------- cni-plugin.sh
infrastructure.sh <-----|
                        +------- inter-node-routes.sh
```

For example, you can run `kubernetes.sh` only after running `infrastructure.sh`.

### Installing

#### 1. Creating the GCP infrastructure

```bash
./infrastructure.sh up
```

#### 2. Installing Kubernetes

```bash
./kubernetes.sh up
```

All the nodes are `NotReady`, because there is no CNI plugin installed.

#### 3. Installing the CNI plugin

```bash
./cni-plugin.sh up
```

The nodes automatically become ready as the kubelet detects the CNI plugin.

You may now deploy Pods, for example:

```bash
kubectl apply -f pods.yaml
```

Note that the inter-node communication is provided external to the CNI plugin executable (see next step below). Thus, at the moment, Pods can communicate with Pods on the same node, but Pods **cannot** communicate with Pods on different nodes.

Also the cluster-internal DNS doesn't work, since the DNS Pods cannot be reached.

The next script fixes this.

#### 4. Creating the inter-node communication routes

```bash
./inter-node-routes.sh up
```

Pods can now communicate with Pods on different nodes. Cluster-internal DNS also works.

### Uninstalling

Each script has a `down` command that reverts the changes done by the `up` command. For example:

```bash
./inter-node-routes.sh down
```

You can execute and reexecute the `down` and `up` command according to the interdependencies of the scripts:


To tear down everything, it's enough to run the following two scripts:

```bash
./inter-node-routes.sh down
./infrastructure.sh down
```

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
