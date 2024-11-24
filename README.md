Pi-hole Deployment on k3d with MetalLB

This README documents the steps taken to deploy Pi-hole on a local k3d cluster, integrate it with MetalLB for LoadBalancer IP allocation, configure it as a DNS proxy, and troubleshoot any issues encountered during the setup.
Overview

This project involves deploying Pi-hole on a local k3d Kubernetes cluster for network-wide ad blocking and DNS management. MetalLB is used to provide LoadBalancer functionality for assigning external IPs to Pi-hole services in a local environment.
Prerequisites

    Docker installed
    k3d installed and configured
    kubectl installed
    Helm installed
    Basic networking knowledge (subnets, IP ranges)

Steps
1. Create k3d Cluster

Create a local k3d cluster with the default configuration:

k3d cluster create home-cluster

Verify the cluster is running:

kubectl get nodes

2. Install MetalLB

MetalLB is required to assign external IPs for services in the k3d cluster.
Deploy MetalLB:

kubectl create namespace metallb-system
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml

Configure IP Address Pool:

Ensure the IP pool matches the subnet of the k3d cluster. For this setup, the subnet is 172.18.0.0/16.

Create a configuration file (metallb-config.yaml) with an appropriate IP range:

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

Apply the configuration:

kubectl apply -f metallb-config.yaml

Restart MetalLB to ensure it picks up the changes:

kubectl rollout restart deployment/controller -n metallb-system
kubectl rollout restart daemonset/speaker -n metallb-system

3. Install Pi-hole
Clone the Helm Chart:

helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo update
helm pull mojo2600/pihole --untar

Customize values.yaml:

Modify values.yaml to:

    Expose the web interface via a NodePort.
    Assign LoadBalancer services for DNS (TCP and UDP).

Example values.yaml:

service:
  web:
    type: NodePort
    externalPort: 30080
  dns:
    enabled: true
    type: LoadBalancer
  dhcp:
    enabled: false

persistence:
  enabled: true
  existingClaim: ""
admin:
  password: "yourpassword"

Install the Chart:

helm install pihole ./pihole -f values.yaml

4. Configure Router

    Access your router's admin interface.
    Set Primary DNS to the Pi-hole's LoadBalancer external IP for UDP (172.18.0.102).
    Optionally, set Secondary DNS to the TCP IP (172.18.0.101).
    Save and reboot the router.

5. Verify and Monitor

    Access the Pi-hole web interface at http://<EXTERNAL-IP>:30080/admin.
    Check the Query Log to confirm that devices are routing DNS requests through Pi-hole.

Troubleshooting
Issue: MetalLB Not Assigning External IPs

    Verify MetalLB configuration:

kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system

Ensure the IP pool matches the k3d subnet:

docker network inspect <k3d-network-name>

Restart MetalLB components:

    kubectl rollout restart deployment/controller -n metallb-system
    kubectl rollout restart daemonset/speaker -n metallb-system

Issue: nslookup Fails to Reach Pi-hole

    Verify Pi-hole pods are running:

kubectl get pods -l app.kubernetes.io/name=pihole

Check logs for errors:

kubectl logs -l app.kubernetes.io/name=pihole

Test connectivity:

    ping <LoadBalancer-IP>
    nslookup google.com <LoadBalancer-IP>

Issue: Pi-hole Query Log Shows No Traffic

    Confirm the router's DNS settings are pointing to the correct Pi-hole IPs.
    Flush DNS cache on devices:
        Windows: ipconfig /flushdns
        macOS: sudo killall -HUP mDNSResponder
        Linux: sudo systemd-resolve --flush-caches

Issue: Port Conflicts

    Adjust externalPort settings in values.yaml if another service is using the same port.


