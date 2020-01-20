{
  "cniVersion": "0.3.1",
  "name": "my-pod-network",
  "type": "my-cni-plugin",
  "myHostNetwork": std.extVar("hostNetwork"),
  "myPodNetwork": std.extVar("podNetwork"),
  "myPodSubnet": std.extVar("podSubnet")
}
