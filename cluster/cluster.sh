#!/bin/bash

set -e

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
host_cidr=10.0.0.0/16
pod_cidr=200.200.0.0/16

# Create cluster
up() {

  #------------------------------------------------------------------------------#
  # TODO: create new project and create all resources in this project
  #------------------------------------------------------------------------------#

  #------------------------------------------------------------------------------#
  # Create GCP infrastructure
  #------------------------------------------------------------------------------#

  gcloud compute networks create "$vpc" --subnet-mode custom
  gcloud compute networks subnets create "$subnet" --network "$vpc" --range "$host_cidr"
  gcloud compute firewall-rules create "$firewall_internal" --network "$vpc" --allow tcp,udp,icmp --source-ranges "$host_cidr"
  gcloud compute firewall-rules create "$firewall_ingress" --network "$vpc" --allow tcp:22,tcp:6443,icmp
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
  # Allow firewall rules to settle (SSH access fails if trying to early)
  sleep 10

  #------------------------------------------------------------------------------#
  # Install kubeadm on VM instances
  #------------------------------------------------------------------------------#

  script=$(mktemp)
  cat <<EOF >"$script"
#!/bin/bash

sudo apt-get update
sudo apt-get install -y docker.io apt-transport-https curl jq
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubeadm
EOF

  for node in "$master" "$worker1" "$worker2"; do
    gcloud compute scp "$script" "$node":install-kubeadm.sh
    gcloud compute ssh "$node" --command "chmod +x install-kubeadm.sh"
    gcloud compute ssh "$node" --command ./install-kubeadm.sh
  done


  #------------------------------------------------------------------------------#
  # Install Kubernetes
  #------------------------------------------------------------------------------#

  # Retrieve external IP address of master VM instance
  MASTER_IP=$(gcloud compute instances describe "$master" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')

  # Run 'kubeadm init' on master node, capture 'kubeadm join' command
  kubeadm_join=$(gcloud compute ssh "$master" --command "sudo kubeadm init --apiserver-cert-extra-sans=\"$MASTER_IP\" --pod-network-cidr=\"$pod_cidr\"" | tail -n 2)

  # Run 'kubeadm join' on worker nodes
  for node in "$worker1" "$worker2"; do
    gcloud compute ssh root@"$node" --command "$kubeadm_join"
  done

  #------------------------------------------------------------------------------#
  # Set up kubectl access
  #------------------------------------------------------------------------------#

  gcloud compute scp root@"$master":/etc/kubernetes/admin.conf "$kubeconfig"
  sed -i -r "s#[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443#$MASTER_IP:6443#" "$kubeconfig"
  export KUBECONFIG=$(pwd)/"$kubeconfig"

  #------------------------------------------------------------------------------#
  # Test access
  #------------------------------------------------------------------------------#

  if grep -q "$MASTER_EXTERNAL_IP" <<<$(kubectl cluster-info); then
    echo -e 'Yay! You can access your cluster now.\n\nTry it:\n\n$kubectl get nodes'
    kubectl get nodes
  else
    echo "Something went wrong :("
  fi
}

# Tear down cluster
down() {
  gcloud compute instances delete "$master" "$worker1" "$worker2"
  gcloud compute firewall-rules delete "$firewall_ingress" "$firewall_internal"
  gcloud compute networks subnets delete "$subnet"
  gcloud compute networks delete "$vpc"
  rm "$KUBECONFIG"
  unset KUBECONFIG
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
