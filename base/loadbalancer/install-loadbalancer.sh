#!/bin/bash

##############################################################################
# Install a software load balancer to enable the use odf external IP addresses
##############################################################################

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
# envsubst is installed via 'brew install gettext' on macOS
# On Windows an executable can be downloaded from here:
# - https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst.exe
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
# Wait for the load balancer to become available
#
echo 'Waiting for the load balancer to come up ...'
sleep 5
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=300s
