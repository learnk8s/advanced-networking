#!/bin/bash

#------------------------------------------------------------------------------#
# Parameters
#------------------------------------------------------------------------------#

vpc=my-k8s-vpc
subnet=my-k8s-subnet
firewall_internal=my-k8s-internal
firewall_ingress=my-k8s-ingress
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2
kubeconfig=my-kubeconfig
host_net=10.0.0.0/16
pod_net=200.200.0.0/16

# Create cluster
up() {
  set -e

  #------------------------------------------------------------------------------#
  # Create GCP infrastructure
  #------------------------------------------------------------------------------#

  gcloud compute networks create "$vpc" --subnet-mode custom
  gcloud compute networks subnets create "$subnet" --network "$vpc" --range "$host_net"
  gcloud compute instances create "$master" \
      --machine-type n1-standard-2 \
      --subnet "$subnet" \
      --image-family ubuntu-1804-lts \
      --image-project ubuntu-os-cloud \
      --can-ip-forward
  gcloud compute instances create "$worker1" "$worker2" \
      --machine-type n1-standard-1 \
      --subnet "$subnet" \
      --image-family ubuntu-1804-lts \
      --image-project ubuntu-os-cloud \
      --can-ip-forward
  gcloud compute firewall-rules create "$firewall_internal" --network "$vpc" --allow tcp,udp,icmp --source-ranges "$host_net","$pod_net"
  gcloud compute firewall-rules create "$firewall_ingress" --network "$vpc" --allow tcp:22,tcp:6443

  # Wait for SSH access to succeed before proceeding (may take up to 30 sec.)
  while ! gcloud compute ssh "$master" --command "echo test" &>/dev/null; do
    echo "Waiting for SSH access..."
    sleep 10
  done

  #------------------------------------------------------------------------------#
  # Install kubeadm on VM instances
  #------------------------------------------------------------------------------#

  install_kubeadm=$(mktemp)
  cat <<EOF >"$install_kubeadm"
#!/bin/bash

sudo apt-get update
sudo apt-get install -y docker.io apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubeadm
EOF

  for node in "$master" "$worker1" "$worker2"; do
    gcloud compute scp "$install_kubeadm" "$node":install-kubeadm.sh
    gcloud compute ssh "$node" --command "chmod +x install-kubeadm.sh"
    gcloud compute ssh "$node" --command ./install-kubeadm.sh
  done

  #------------------------------------------------------------------------------#
  # Install Kubernetes
  #------------------------------------------------------------------------------#

  # Retrieve external IP address of master VM instance
  MASTER_IP=$(gcloud compute instances describe "$master" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')

  # Run 'kubeadm init' on master node, capture 'kubeadm join' command
  kubeadm_join=$(gcloud compute ssh "$master" --command "sudo kubeadm init --apiserver-cert-extra-sans=\"$MASTER_IP\" --pod-network-cidr=\"$pod_net\"" | tail -n 2)

  # Run 'kubeadm join' on worker nodes
  for node in "$worker1" "$worker2"; do
    gcloud compute ssh root@"$node" --command "$kubeadm_join"
  done

  #------------------------------------------------------------------------------#
  # Download and customise kubeconfig file
  #------------------------------------------------------------------------------#

  gcloud compute scp root@"$master":/etc/kubernetes/admin.conf "$kubeconfig"
  sed -i -r "s#[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443#$MASTER_IP:6443#" "$kubeconfig"
  export KUBECONFIG=$(pwd)/"$kubeconfig"

  #------------------------------------------------------------------------------#
  # Verify cluster access from local machine
  #------------------------------------------------------------------------------#

  if ! grep -q "$MASTER_EXTERNAL_IP" <<<$(kubectl cluster-info); then
    echo "Hmm, can't access your cluster... 🤔"
    exit 1
  fi

  #------------------------------------------------------------------------------#
  # Create inter-node Pod network routes
  #------------------------------------------------------------------------------#

  for node in "$master" "$worker1" "$worker2"; do
    node_ip=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    pod_node_subnet=$(kubectl get node "$node" -o jsonpath='{.spec.podCIDR}')
    gcloud compute routes create to-pods-on-"$node" --network="$vpc" --destination-range="$pod_node_subnet" --next-hop-address="$node_ip"
  done

  #------------------------------------------------------------------------------#
  # Install additional dependencies on VM instances
  #------------------------------------------------------------------------------#

  for node in "$master" "$worker1" "$worker2"; do
    gcloud compute ssh "$node" --command "sudo apt-get install jq nmap"
  done

  #------------------------------------------------------------------------------#
  # Done!
  #------------------------------------------------------------------------------#

  cat <<EOF

*******************************************
😃 Yay! You can access your cluster now. 😃
*******************************************

But first you have to set the following environment variable:

👉 👉 export KUBECONFIG=$(pwd)/$kubeconfig 👈 👈 

Then you can access your cluster as usual.

For example:

$ kubectl get nodes
EOF
  kubectl get nodes
}

# Delete all resources and settings created by 'up'
down() {
  set -B  # Ensure brace expansion is enabled
  gcloud -q compute routes delete to-pods-on-{"$master","$worker1","$worker2"}
  gcloud -q compute instances delete "$master" "$worker1" "$worker2"
  gcloud -q compute firewall-rules delete "$firewall_ingress" "$firewall_internal"
  gcloud -q compute networks subnets delete "$subnet"
  gcloud -q compute networks delete "$vpc"
  rm -f "$KUBECONFIG"
  cat <<EOF

***************************
🗑️  All resources deleted 🗑️
***************************

Run the following command to remove even the last traces:

👉 👉 unset KUBECONFIG 👈 👈 

EOF
}

usage() {
  echo "USAGE:"
  echo "  $(basename $0) up|down"
}

case "$1" in
  up) up ;;
  down) down ;;
  *) usage && exit 1 ;;
esac
