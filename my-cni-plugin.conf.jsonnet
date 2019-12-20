{
  "cniVersion": "0.3.1",
  "name": "my-pod-network",
  "type": "my-cni-plugin",
  "myPodCidrRange": std.extVar("podCIDR")
}
