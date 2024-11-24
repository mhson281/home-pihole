# Pi-hole Deployment on k3d with MetalLB

This README documents the steps taken to deploy Pi-hole on a local k3d cluster, integrate it with MetalLB for LoadBalancer IP allocation, configure it as a DNS proxy, and troubleshoot any issues encountered during the setup.

## Overview

This project involves deploying Pi-hole on a local k3d Kubernetes cluster for network-wide ad blocking and DNS management. MetalLB is used to provide LoadBalancer functionality for assigning external IPs to Pi-hole services in a local environment.

## Prerequisites

- Docker installed
- k3d installed and configured
- kubectl installed
- Helm installed
- Basic networking knowledge (subnets, IP ranges)

## Intallation Steps

1. Create k3d Cluster

Create a local k3d cluster with the default configuration:

```bash
k3d cluster create home-cluster
```

Verify the cluster is running:

```bash
kubectl get nodes
```

2. Install MetalLB

MetalLB is required to assign external IPs for services in the k3d cluster.

Deploy MetalLB (run these command or mettallb.sh):

```bash
kubectl create namespace metallb-system
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml
```
Configure IP Address Pool:

Ensure the IP pool matches the subnet of the k3d cluster. For this setup, the subnet is 172.18.0.0/16.

Create a configuration file (metallb-config.yaml) with an appropriate IP range:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ip-pool
  namespace: metallb-system
spec:
  addresses:
    - 172.18.0.100-172.18.0.150
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
    - ip-pool

```

Apply the configuration:

```bash
kubectl apply -f metallb-config.yaml
```

Restart MetalLB to ensure it picks up the changes:

```
kubectl rollout restart deployment/controller -n metallb-system
kubectl rollout restart daemonset/speaker -n metallb-system
```

3. Install Pi-hole
Clone the Helm Chart:

```bash
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo update
helm pull mojo2600/pihole --untar
```
Modify values.yaml to:

- Expose the web interface via a NodePort.
- Assign LoadBalancer services for DNS (TCP and UDP).

Example values.yaml:

```yaml
serviceWeb:
  http:
    enabled: true
    port: 80
  https:
    enabled: false
    port: 443
    nodePort: ""
  type: NodePort
serviceDns:
  type: LoadBalancer
  port: 53
  nodePort: ""
```

Install the Chart:

```bash
helm install pihole ./pihole -f values.yaml
```

4. Configure Router

- Access your router's admin interface.
- Set Primary DNS to the Pi-hole's LoadBalancer external IP for UDP (172.18.0.100).
- Optionally, set Secondary DNS to the TCP IP (172.18.0.101).
- Save and reboot the router(must be rebooted for change to take place)

5. Verify and Monitor

- Access the Pi-hole web interface at http://<EXTERNAL-IP>:<port>/admin.
- Check the Query Log to confirm that devices are routing DNS requests through Pi-hole.

## Troubleshooting

### Issue: MetalLB Not Assigning External IPs

Verify MetalLB configuration:

```bash
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

Ensure the IP pool matches the k3d subnet:

```bash
docker network ls # look for k3d network name
docker network inspect <k3d-network-name>
```

Restart MetalLB components:

```bash
kubectl rollout restart deployment/controller -n metallb-system
kubectl rollout restart daemonset/speaker -n metallb-system
```

### Issue: nslookup Fails to Reach Pi-hole

Verify Pi-hole pods are running:

```bash
kubectl get pods -l app.kubernetes.io/name=pihole
```

Check logs for errors:

```bash
kubectl logs -l app.kubernetes.io/name=pihole
```

Test connectivity:

```bash
ping <LoadBalancer-IP>
nslookup google.com <LoadBalancer-IP>
```

### Issue: Pi-hole Query Log Shows No Traffic

Confirm the router's DNS settings are pointing to the correct Pi-hole IPs.
Flush DNS cache on devices:
    - Windows: ipconfig /flushdns
    - macOS: sudo killall -HUP mDNSResponder
    - Linux: sudo systemd-resolve --flush-caches

### Issue: Port Conflicts

Adjust externalPort settings in values.yaml if another service is using the same port.


