{
  "cniVersion": "0.3.1",
  "name": "my-pod-network",
  "type": "my-cni-plugin",
  "myPodNet": std.extVar("podNet"),
  "myPodNodeSubnet": std.extVar("podNodeSubnet")
}
