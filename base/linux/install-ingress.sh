#!/bin/bash

################################################################################################
# Install ingress for a Linux host, where we can simulate a cloud platform and its load balancer
################################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# For Linux we install the MetalLB load balancer
# There is no point installing this on macOS or Windows since it cannot be called reliably
# https://www.thehumblelab.com/kind-and-metallb-on-mac/
#
echo 'Creating the software load balancer ...'
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered deploying the software load balancer'
  exit 1
fi

#
# Get the KIND network CIDR and create IP address ranges that MetalLB will use
# https://medium.com/@charled.breteche/kind-cilium-metallb-and-no-kube-proxy-a9fe66ddfad6
#
KIND_NET_CIDR=$(docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}')
METALLB_IP_START=$(echo ${KIND_NET_CIDR} | sed "s@0.0/16@255.1@")
METALLB_IP_END=$(echo ${KIND_NET_CIDR} | sed "s@0.0/16@255.250@")
METALLB_IP_RANGE="${METALLB_IP_START}-${METALLB_IP_END}"

#
# Update the MetalLB configuration
#
echo 'Configuring the load balancer IP address range ...'
export METALLB_IP_RANGE
envsubst < ./metallb-config-template.yaml > ./metallb-config.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered creating the MetalLB configuration'
  exit 1
fi

#
# Configure MetalLB with IP addresses to distribute to services of type LoadBalancer
#
kubectl -n metallb-system delete -f ./metallb-config.yaml 2>/dev/null
kubectl -n metallb-system apply  -f ./metallb-config.yaml
if [ $? -ne 0 ]; then
  echo '*** Problem encountered reconfiguring MetalLB'
  exit 1
fi

#
# Install a customized Kong ingress controller
#
../kong/install-kong.sh
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing Kong ingress'
  exit 1
fi

#
# Wait for the Ingress resources to be created
#
kubectl wait --namespace kong \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=app \
--timeout=300s

#
# Indicate the 'external' IP address used to call into the cluster
#
CLUSTER_IP=$(kubectl -n kong get svc kong-kong-proxy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "The cluster's external IP address is $CLUSTER_IP ..."
