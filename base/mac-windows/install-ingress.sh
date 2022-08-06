#!/bin/bash

##################################################################################################################################
# Install ingress for a macOS or Windows host, where it requires special handling to call into the cluster without port forwarding
# Docker Desktop's network is not exposed to the host computer by default, and a patched Ingress controller provides connectivity
##################################################################################################################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Install the Kong open source ingress controller in a stateless setup
#
echo 'Installing ingress resources ...'
helm repo add kong https://charts.konghq.com 1>/dev/null
helm repo update
helm uninstall kong --namespace kong 2>/dev/null
helm install kong kong/kong --values ../kong/helm-values.yaml --namespace kong --create-namespace
if [ $? -ne 0 ]; then
  echo '*** Problem encountered installing ingress resources'
  exit 1
fi

#
# Apply KIND specific patches needed on macOS and Windows, to provide connectivity to the host computer
# These use extraPortMappings from cluster.yaml and allow the host computer to connect to the Ingress directly
# https://kind.sigs.k8s.io/docs/user/ingress/
#
kubectl patch service -n kong kong-kong-proxy -p '{"spec":{"type":"NodePort"}}'
kubectl patch deployment -n kong kong-kong --patch-file ./kong-kind-patches.json
if [ $? -ne 0 ]; then
  echo '*** Problem encountered applying KIND specific patches for the ingress controller'
  exit 1
fi

#
# Indicate the 'external' IP address used to call into the cluster
#
echo "The cluster's external IP address is 127.0.0.1 ..."
