#!/bin/bash
#
# Install or uninstall Kubernetes on the GCP infrastructure.
#
# Run this after creating the GCP infrastructure with infrastructure.sh.

pod_network=200.200.0.0/16
master=my-k8s-master
worker1=my-k8s-worker-1
worker2=my-k8s-worker-2
kubeconfig=~/my-kubeconfig

install() {

  #------------------------------------------------------------------------------#
  # Install kubeadm
  #------------------------------------------------------------------------------#

  install_kubeadm=$(mktemp)
  cat <<EOF >"$install_kubeadm"
#!/bin/bash

sudo apt-get update
sudo apt-get install -y docker.io apt-transport-https curl jq nmap
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

  # Retrieve master node's external IP address
  MASTER_IP=$(gcloud compute instances describe "$master" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')

  # Run 'kubeadm init' on master node; capture 'kubeadm join' command
  kubeadm_join=$(gcloud compute ssh "$master" --command "sudo kubeadm init --pod-network-cidr=\"$pod_network\" --apiserver-cert-extra-sans=\"$MASTER_IP\"" | tail -n 2)

  # Run 'kubeadm join' on worker nodes
  gcloud compute ssh root@"$worker1" --command "$kubeadm_join"
  gcloud compute ssh root@"$worker2" --command "$kubeadm_join"

  #------------------------------------------------------------------------------#
  # Download and customise kubeconfig file
  #------------------------------------------------------------------------------#

  gcloud compute scp root@"$master":/etc/kubernetes/admin.conf "$kubeconfig"
  sed -i -r "s#[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:6443#$MASTER_IP:6443#" "$kubeconfig"
  export KUBECONFIG=$kubeconfig

  #------------------------------------------------------------------------------#
  # Verify cluster access from local machine
  #------------------------------------------------------------------------------#

  if ! grep -q "$MASTER_IP" <<<$(kubectl cluster-info); then
    echo "Hmm, can't access your cluster... 🤔"
    exit 1
  fi

  cat <<EOF

**************************
😃 Kubernetes installed 😃
**************************

A kubeconfig file was added to your local machine. Please make the
KUBECONFIG environment variable point to it:

👉 export KUBECONFIG=$kubeconfig

Then you can access your cluster as usual, for example:

$ kubectl get nodes
EOF
  kubectl get nodes
}

uninstall() {
  for node in "$worker2" "$worker1" "$master"; do
    gcloud compute ssh root@"$node" --command "kubeadm reset -f"
  done
  rm "$kubeconfig"

  cat <<EOF

****************************
🗑️  Kubernetes uninstalled 🗑️
****************************

To remove all traces on your local machine, unset the KUBECONFIG variable:

👉 unset KUBECONFIG

EOF
}

usage() {
  echo "USAGE:"
  echo "  $(basename $0) install|uninstall"
}

case "$1" in
  install) install;;
  uninstall) uninstall;;
  *) usage && exit 1 ;;
esac
